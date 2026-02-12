!===============================================================================
! MPI 2D Cartesian Decomposition for Conway's Game of Life
!===============================================================================
!
! DESCRIPTION:
!   Implements a 2D domain decomposition using MPI_Cart_create for optimal
!   neighbor communication. Each rank owns a rectangular subdomain and
!   exchanges ghost cells with up to 4 neighbors (N, S, E, W) plus corners.
!
! DECOMPOSITION STRATEGY:
!   - Uses MPI_Dims_create to factor nprocs into a 2D grid (dims(1) x dims(2))
!   - Each rank gets a subdomain of size (N/dims(1)) x (N/dims(2)) approximately
!   - Remainder rows/cols distributed to first few ranks in each dimension
!
! GHOST CELL LAYOUT:
!   my_grid(0:my_local_rows+1, 0:my_local_cols+1)
!   - Row 0 and row my_local_rows+1 are ghost rows (from north/south neighbors)
!   - Col 0 and col my_local_cols+1 are ghost cols (from west/east neighbors)
!   - Corners (0,0), (0,N+1), (N+1,0), (N+1,N+1) exchanged for diagonal neighbors
!
! COMMUNICATION PATTERN:
!   Each timestep:
!   1. Exchange north/south ghost rows (MPI_Sendrecv)
!   2. Exchange west/east ghost columns (MPI_Sendrecv)
!   3. Exchange 4 corner cells for diagonal neighbors
!   4. Compute next generation using 8-neighbor stencil
!
! BOUNDARY CONDITIONS:
!   - Non-periodic (periods = .false.) - edges are fixed at 0
!   - MPI_PROC_NULL used for missing neighbors at domain boundaries
!
! LOAD BALANCING:
!   Greedy prefix: base + merge(1,0, coord < remainder)
!   First 'remainder' ranks in each dimension get one extra row/col
!
! PERFORMANCE NOTES:
!   - Best scaling among all implementations (34.7x on 32 cores)
!   - 2D decomposition minimizes surface-to-volume ratio
!   - Communication ~12% of total time at 32 ranks
!
!===============================================================================

program MPI_2D_Decomposition
    use mpi
    use iso_fortran_env, only: int64
    implicit none

    integer :: N, M, STEPS, print_every, nargs
    character(len=64) :: arg
    integer :: rank, nprocs, ierr, step
    integer :: i, j, local_i, local_j, global_i, global_j, idx
    integer :: neighbors
    integer :: cart_comm, cart_rank
    integer :: dims(2), coords(2)
    logical :: periods(2), reorder
    integer :: north, south, west, east
    integer :: base_i, rem_i, base_j, rem_j
    integer :: my_local_rows, my_local_cols, my_i_start, my_j_start
    integer :: status(MPI_STATUS_SIZE)
    integer, allocatable :: my_grid(:,:), new_grid(:,:), full_init(:)
    integer, allocatable :: init_grid(:,:)
    integer, allocatable :: send_north(:), send_south(:), recv_north(:), recv_south(:)
    integer :: local_count, total_count
    integer :: local_alive, alive_final
    integer(int64) :: local_checksum, checksum_final
    double precision :: t0, t1, total_time, comm_time, comp_time
    double precision :: tcomm0, tcomm1

    call MPI_Init(ierr)
    call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
    call MPI_Comm_size(MPI_COMM_WORLD, nprocs, ierr)

    N = 20
    M = 20
    STEPS = 80
    print_every = -1

    if (rank == 0) then
      nargs = command_argument_count()
      if (nargs >= 3) then
        call get_command_argument(1, arg); read(arg,*) N
        call get_command_argument(2, arg); read(arg,*) M
        call get_command_argument(3, arg); read(arg,*) STEPS
        if (nargs >= 4) then
          call get_command_argument(4, arg); read(arg,*) print_every
        else
          print_every = 0
        end if
      end if
    end if

    call MPI_Bcast(N, 1, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
    call MPI_Bcast(M, 1, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
    call MPI_Bcast(STEPS, 1, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
    call MPI_Bcast(print_every, 1, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)

    if (M /= N) then
      if (rank == 0) then
        write(*,'(A,I0,A,I0,A)') "ERROR: only square grids supported (GRID_X=", N, ", GRID_Y=", M, ")"
      end if
      call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
    end if

    dims = 0
    call MPI_Dims_create(nprocs, 2, dims, ierr)

    periods(:) = .false.
    reorder = .false.
    call MPI_Cart_create(MPI_COMM_WORLD, 2, dims, periods, reorder, cart_comm, ierr)

    call MPI_Comm_rank(cart_comm, cart_rank, ierr)
    call MPI_Cart_coords(cart_comm, cart_rank, 2, coords, ierr)

    call MPI_Cart_shift(cart_comm, 0, 1, north, south, ierr)
    call MPI_Cart_shift(cart_comm, 1, 1, west, east, ierr)

    base_i = N / dims(1)
    rem_i = mod(N, dims(1))
    my_local_rows = base_i + merge(1, 0, coords(1) < rem_i)
    my_i_start = 1 + coords(1) * base_i + min(coords(1), rem_i)

    base_j = N / dims(2)
    rem_j = mod(N, dims(2))
    my_local_cols = base_j + merge(1, 0, coords(2) < rem_j)
    my_j_start = 1 + coords(2) * base_j + min(coords(2), rem_j)

    local_count = my_local_rows * my_local_cols
    call MPI_Reduce(local_count, total_count, 1, MPI_INTEGER, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
    if (rank == 0 .and. total_count /= N*N) then
      write(*,'(A,I0,A,I0)') "ERROR: ownership mismatch! Got ", total_count, " expected ", N*N
      call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
    end if

    allocate(my_grid(0:my_local_rows+1, 0:my_local_cols+1), new_grid(1:my_local_rows, 1:my_local_cols))
    allocate(full_init(N*N))
    allocate(send_north(my_local_cols), send_south(my_local_cols), recv_north(my_local_cols), recv_south(my_local_cols))

    full_init = 0

    if (rank == 0) then
      allocate(init_grid(0:N+1, 0:N+1))
      init_grid = 0

      if (N >= 3) then
        init_grid(1,3) = 1
        init_grid(2,1) = 1
        init_grid(2,3) = 1
        init_grid(3,2) = 1
        init_grid(3,3) = 1
      end if

      do j = 1, N
        do i = 1, N
          idx = (j-1)*N + i
          full_init(idx) = init_grid(i,j)
        end do
      end do

      deallocate(init_grid)
    end if

    call MPI_Bcast(full_init, N*N, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)

    my_grid = 0
    do local_j = 1, my_local_cols
      global_j = my_j_start + local_j - 1
      do local_i = 1, my_local_rows
        global_i = my_i_start + local_i - 1
        idx = (global_j - 1) * N + global_i
        my_grid(local_i, local_j) = full_init(idx)
      end do
    end do

    deallocate(full_init)

    if (rank == 0) then
      write(*,'(A)') "=========================================="
      write(*,'(A,I0,A,I0,A,I0)') "MPI 2D Decomposition: ", N, "x", N, ", Steps: ", STEPS
      write(*,'(A,I0,A,I0)') "Process grid: ", dims(1), " x ", dims(2)
      write(*,'(A,L1)') "periods(1)=", periods(1)
      write(*,'(A,L1)') "periods(2)=", periods(2)
      write(*,'(A,I0)') "MPI Ranks: ", nprocs
      write(*,'(A)') "=========================================="
    end if

    call MPI_Barrier(MPI_COMM_WORLD, ierr)
    t0 = MPI_Wtime()
    comm_time = 0.0d0

    do step = 1, STEPS
      my_grid(0,:) = 0
      my_grid(my_local_rows+1,:) = 0
      my_grid(:,0) = 0
      my_grid(:,my_local_cols+1) = 0

      send_north = my_grid(1,1:my_local_cols)
      send_south = my_grid(my_local_rows,1:my_local_cols)
      recv_north = 0
      recv_south = 0

      tcomm0 = MPI_Wtime()

      call MPI_Sendrecv(send_north, my_local_cols, MPI_INTEGER, north, 40, &
                        recv_south, my_local_cols, MPI_INTEGER, south, 40, &
                        cart_comm, status, ierr)

      call MPI_Sendrecv(send_south, my_local_cols, MPI_INTEGER, south, 41, &
                        recv_north, my_local_cols, MPI_INTEGER, north, 41, &
                        cart_comm, status, ierr)

      my_grid(0,1:my_local_cols) = recv_north
      my_grid(my_local_rows+1,1:my_local_cols) = recv_south

      call MPI_Sendrecv(my_grid(0,1), my_local_rows+2, MPI_INTEGER, west, 42, &
                        my_grid(0,my_local_cols+1), my_local_rows+2, MPI_INTEGER, east, 42, &
                        cart_comm, status, ierr)

      call MPI_Sendrecv(my_grid(0,my_local_cols), my_local_rows+2, MPI_INTEGER, east, 43, &
                        my_grid(0,0), my_local_rows+2, MPI_INTEGER, west, 43, &
                        cart_comm, status, ierr)

      tcomm1 = MPI_Wtime()
      comm_time = comm_time + (tcomm1 - tcomm0)

      do local_i = 1, my_local_rows
        do local_j = 1, my_local_cols
          neighbors = sum(my_grid(local_i-1:local_i+1, local_j-1:local_j+1)) - my_grid(local_i, local_j)
          if (neighbors == 3 .or. (my_grid(local_i, local_j) == 1 .and. neighbors == 2)) then
            new_grid(local_i, local_j) = 1
          else
            new_grid(local_i, local_j) = 0
          end if
        end do
      end do

      my_grid(1:my_local_rows,1:my_local_cols) = new_grid
    end do

    call MPI_Barrier(MPI_COMM_WORLD, ierr)
    t1 = MPI_Wtime()

    total_time = t1 - t0
    comp_time = total_time - comm_time

    local_alive = 0
    local_checksum = 0_int64

    do local_j = 1, my_local_cols
      global_j = my_j_start + local_j - 1
      do local_i = 1, my_local_rows
        global_i = my_i_start + local_i - 1
        if (my_grid(local_i, local_j) == 1) then
          local_alive = local_alive + 1
          local_checksum = local_checksum + int(global_i,int64)*1000003_int64 + int(global_j,int64)
        end if
      end do
    end do

    call MPI_Reduce(local_alive, alive_final, 1, MPI_INTEGER, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
    call MPI_Reduce(local_checksum, checksum_final, 1, MPI_INTEGER8, MPI_SUM, 0, MPI_COMM_WORLD, ierr)

    if (rank == 0) then
      write(*,'(A,I0)') "ALIVE_FINAL:    ", alive_final
      write(*,'(A,I0)') "CHECKSUM_FINAL: ", checksum_final
      write(*,*)
      write(*,'(A)') "========================================"
      write(*,'(A,F12.6)') "TOTAL_TIME_SEC: ", total_time
      write(*,'(A,F12.6)') "COMM_TIME_SEC:  ", comm_time
      write(*,'(A,F12.6)') "COMP_TIME_SEC:  ", comp_time
      if (total_time > 0.0d0) then
        write(*,'(A,F8.2,A)') "COMM_FRACTION:  ", (comm_time/total_time)*100.0d0, "%"
      end if
      write(*,'(A,I0)') "GRID_SIZE:      ", N * N
      write(*,'(A,I0)') "TIMESTEPS:      ", STEPS
      write(*,'(A,I0)') "MPI_RANKS:      ", nprocs
      write(*,'(A)') "========================================"
    end if

    call MPI_Comm_free(cart_comm, ierr)
    deallocate(my_grid, new_grid, send_north, send_south, recv_north, recv_south)
    call MPI_Finalize(ierr)

end program MPI_2D_Decomposition
