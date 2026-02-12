!===============================================================================
! MPI Row Decomposition for Conway's Game of Life
!===============================================================================
!
! DESCRIPTION:
!   Implements a 1D horizontal (row) decomposition. The global NxN grid is
!   split into horizontal strips, with each rank owning a contiguous block
!   of rows. Communication occurs only with north/south neighbors.
!
! DECOMPOSITION STRATEGY:
!   - Rank k owns rows [my_row_start, my_row_start + my_local_rows - 1]
!   - my_local_rows = N/nprocs + (rank < N mod nprocs ? 1 : 0)
!   - my_row_start = 1 + rank*base + min(rank, remainder)
!
! GHOST CELL LAYOUT:
!   my_grid(0:my_local_rows+1, 0:N+1)
!   - Row 0: ghost row from north neighbor
!   - Row my_local_rows+1: ghost row from south neighbor
!   - Columns 0 and N+1: fixed boundary (always 0)
!
! COMMUNICATION PATTERN:
!   Each timestep:
!   1. Send my_grid(1,:) north, receive into my_grid(my_local_rows+1,:)
!   2. Send my_grid(my_local_rows,:) south, receive into my_grid(0,:)
!   3. Compute next generation using 8-neighbor stencil
!
! PERFORMANCE NOTES:
!   - Simple communication pattern (only 2 neighbors)
!   - Poor cache utilization in Fortran (column-major storage)
!   - Slowest of the MPI implementations due to memory access patterns
!   - ~23x speedup at 32 ranks (vs 34.7x for 2D)
!
! BOUNDARY CONDITIONS:
!   - North/south boundaries: ghost exchange with neighbors
!   - East/west boundaries: fixed at 0 (columns 0 and N+1)
!   - MPI_PROC_NULL for ranks at domain edges
!
!===============================================================================

program Row_Decomposition
    use mpi
    use iso_fortran_env, only: int64
    implicit none

    integer :: N, M, STEPS, print_every, nargs
    character(len=64) :: arg
    integer :: rank, nprocs, ierr, step
    integer :: i, j, local_i, local_j, global_i, global_j, idx
    integer :: neighbors
    integer :: base_rows, rem_rows
    integer :: my_local_rows, my_local_cols, my_i_start, my_j_start
    integer :: top, bottom
    integer :: status(MPI_STATUS_SIZE)
    integer, allocatable :: my_grid(:,:), new_grid(:,:), full_init(:)
    integer, allocatable :: init_grid(:,:)
    integer, allocatable :: send_top(:), send_bottom(:), recv_top(:), recv_bottom(:)
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

    base_rows = N / nprocs
    rem_rows = mod(N, nprocs)

    my_local_rows = base_rows + merge(1, 0, rank < rem_rows)
    my_i_start = 1 + rank * base_rows + min(rank, rem_rows)
    my_j_start = 1
    my_local_cols = N

    local_count = my_local_rows * my_local_cols
    call MPI_Reduce(local_count, total_count, 1, MPI_INTEGER, MPI_SUM, 0, MPI_COMM_WORLD, ierr)
    if (rank == 0 .and. total_count /= N*N) then
      write(*,'(A,I0,A,I0)') "ERROR: ownership mismatch! Got ", total_count, " expected ", N*N
      call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
    end if

    allocate(my_grid(0:my_local_rows+1, 0:my_local_cols+1), new_grid(1:my_local_rows, 1:my_local_cols))
    allocate(full_init(N*N))
    allocate(send_top(my_local_cols), send_bottom(my_local_cols), recv_top(my_local_cols), recv_bottom(my_local_cols))

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

    top = merge(rank - 1, MPI_PROC_NULL, rank > 0)
    bottom = merge(rank + 1, MPI_PROC_NULL, rank < nprocs - 1)

    if (rank == 0) then
      write(*,'(A)') "=========================================="
      write(*,'(A,I0,A,I0,A,I0)') "Row Decomposition: ", N, "x", N, ", Steps: ", STEPS
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

      send_top = my_grid(1,1:my_local_cols)
      send_bottom = my_grid(my_local_rows,1:my_local_cols)
      recv_top = 0
      recv_bottom = 0

      tcomm0 = MPI_Wtime()

      call MPI_Sendrecv(send_top, my_local_cols, MPI_INTEGER, top, 10, &
                        recv_bottom, my_local_cols, MPI_INTEGER, bottom, 10, &
                        MPI_COMM_WORLD, status, ierr)

      call MPI_Sendrecv(send_bottom, my_local_cols, MPI_INTEGER, bottom, 11, &
                        recv_top, my_local_cols, MPI_INTEGER, top, 11, &
                        MPI_COMM_WORLD, status, ierr)

      my_grid(0,1:my_local_cols) = recv_top
      my_grid(my_local_rows+1,1:my_local_cols) = recv_bottom

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

    deallocate(my_grid, new_grid, send_top, send_bottom, recv_top, recv_bottom)
    call MPI_Finalize(ierr)

end program Row_Decomposition
