!===============================================================================
! Serial Implementation of Conway's Game of Life
!===============================================================================
!
! DESCRIPTION:
!   Reference serial implementation for correctness validation and baseline
!   timing. All MPI implementations must produce identical CHECKSUM_FINAL
!   values for the same grid size and step count.
!
! GRID LAYOUT:
!   grid(0:N+1, 0:N+1)
!   - Interior cells: grid(1:N, 1:N) contain the actual game state
!   - Boundary cells: rows/cols 0 and N+1 are always 0 (fixed boundaries)
!
! INITIALIZATION:
!   Deterministic pattern (glider) placed at fixed position:
!   - grid(1,3) = 1
!   - grid(2,1) = 1
!   - grid(2,3) = 1
!   - grid(3,2) = 1
!   - grid(3,3) = 1
!   This produces CHECKSUM_FINAL = 22000092 for N=64, STEPS=100
!
! GAME RULES (Conway's Game of Life):
!   - Live cell with 2-3 neighbors survives
!   - Dead cell with exactly 3 neighbors becomes alive
!   - All other cells die or stay dead
!
! OUTPUT:
!   - ALIVE_FINAL: count of live cells at end
!   - CHECKSUM_FINAL: weighted sum for correctness validation
!   - TOTAL_TIME_SEC: wall-clock time for all timesteps
!
! USAGE:
!   ./serial N M STEPS PRINT_EVERY
!   - N, M: grid dimensions (must be equal, only square grids supported)
!   - STEPS: number of timesteps to simulate
!   - PRINT_EVERY: print interval (0 = no intermediate output)
!
!===============================================================================

program Game_of_Life_Serial
    use iso_fortran_env, only: int64
    implicit none

    integer :: N, M, STEPS, print_every, nargs
    character(len=64) :: arg
    integer, allocatable :: grid(:,:), new_grid(:,:)
    integer :: step, i, j, neighbors
    integer :: alive_count
    integer(int64) :: checksum
    real(8) :: t0, t1, total_time

    N = 20
    M = 20
    STEPS = 80
    print_every = -1

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

    if (M /= N) then
      write(*,'(A,I0,A,I0,A)') "ERROR: only square grids supported (GRID_X=", N, ", GRID_Y=", M, ")"
      stop 1
    end if

    allocate(grid(0:N+1,0:N+1), new_grid(1:N,1:N))

    grid = 0
    if (N >= 3) then
      grid(1,3) = 1
      grid(2,1) = 1
      grid(2,3) = 1
      grid(3,2) = 1
      grid(3,3) = 1
    end if

    call apply_dead_boundaries(grid, N)

    if (print_every == -1) then
      write(*,'(A)') "=========================================="
      write(*,'(A)') "Serial Game of Life Reference"
      write(*,'(A,I0,A,I0,A,I0)') "Grid: ", N, "x", N, ", Steps: ", STEPS
      write(*,'(A)') "Pattern: Glider at top-left corner"
      write(*,'(A)') "=========================================="
    else
      write(*,'(A)') "=========================================="
      write(*,'(A,I0,A,I0,A,I0)') "Serial GoL: ", N, "x", N, ", Steps: ", STEPS
      write(*,'(A)') "=========================================="
    end if

    if (print_every > 0) then
      write(*,'(A,I0)') "Step 0 alive: ", sum(grid(1:N,1:N))
    end if

    call cpu_time(t0)

    do step = 1, STEPS
      do i = 1, N
        do j = 1, N
          neighbors = sum(grid(i-1:i+1, j-1:j+1)) - grid(i,j)
          if (neighbors == 3 .or. (grid(i,j) == 1 .and. neighbors == 2)) then
            new_grid(i,j) = 1
          else
            new_grid(i,j) = 0
          end if
        end do
      end do

      grid(1:N,1:N) = new_grid
      call apply_dead_boundaries(grid, N)

      if (print_every > 0) then
        if (mod(step, print_every) == 0) then
          write(*,'(A,I0,A,I0)') "Step ", step, " alive: ", sum(grid(1:N,1:N))
        end if
      end if
    end do

    call cpu_time(t1)
    total_time = t1 - t0

    alive_count = 0
    checksum = 0_int64
    do j = 1, N
      do i = 1, N
        if (grid(i,j) == 1) then
          alive_count = alive_count + 1
          checksum = checksum + int(i,int64)*1000003_int64 + int(j,int64)
        end if
      end do
    end do

    write(*,*)
    write(*,'(A)') "========================================"
    write(*,'(A,F12.6)') "TOTAL_TIME_SEC: ", total_time
    write(*,'(A,I0)') "ALIVE_FINAL:    ", alive_count
    write(*,'(A,I0)') "CHECKSUM_FINAL: ", checksum
    write(*,'(A,I0)') "GRID_SIZE:      ", N * N
    write(*,'(A,I0)') "TIMESTEPS:      ", STEPS
    write(*,'(A)') "========================================"

    deallocate(grid, new_grid)

contains

    subroutine apply_dead_boundaries(g, n)
      integer, intent(in) :: n
      integer, intent(inout) :: g(0:n+1,0:n+1)

      g(0,:) = 0
      g(n+1,:) = 0
      g(:,0) = 0
      g(:,n+1) = 0
    end subroutine apply_dead_boundaries

end program Game_of_Life_Serial
