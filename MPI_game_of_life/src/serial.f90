program Game_of_Life_Serial
    implicit none
    
    ! Benchmark mode: Command-line configurable parameters
    integer :: N, STEPS, print_every, nargs
    character(len=64) :: arg
    integer, allocatable :: grid(:,:), new_grid(:,:)
    integer :: step, i, j, alive
    real(8) :: t0, t1, total_time
  
    ! ========== COMMAND-LINE ARGUMENT PARSING ==========
    N = 20
    STEPS = 80
    print_every = -1   ! -1 = demo schedule
    
    nargs = command_argument_count()
    
    if (nargs >= 3) then
      call get_command_argument(1, arg); read(arg,*) N
      call get_command_argument(2, arg); read(arg,*) N
      call get_command_argument(3, arg); read(arg,*) STEPS
      if (nargs >= 4) then
        call get_command_argument(4, arg); read(arg,*) print_every
      else
        print_every = 0
      end if
    end if
    
    allocate(grid(0:N+1,0:N+1), new_grid(1:N,1:N))
  
    ! Initialize
    grid = 0
    if (N >= 3) then
      grid(1,3) = 1
      grid(2,1) = 1
      grid(2,3) = 1
      grid(3,2) = 1
      grid(3,3) = 1
    end if
  
    call update_boundaries(grid, N)
  
    if (print_every == -1) then
      print *, "=========================================="
      print *, "Serial Game of Life Reference"
      print '(A,I0,A,I0,A,I0)', "Grid: ", N, "x", N, ", Steps: ", STEPS
      print *, "Pattern: Glider at top-left corner"
      print *, "=========================================="
    else
      print '(A)', "=========================================="
      print '(A,I0,A,I0,A,I0)', "Serial GoL: ", N, "x", N, ", Steps: ", STEPS
      print '(A)', "=========================================="
    end if
  
    if (print_every == -1 .or. print_every > 0) then
      print *, ""
      print *, "Step 0: Alive =", sum(grid(1:N,1:N))
      if (N <= 50 .or. print_every == -1) then
        call print_grid(grid(1:N,1:N))
      end if
    end if
  
    call cpu_time(t0)
  
    do step = 1, STEPS
      do i = 1, N
        do j = 1, N
          alive = count_neighbors(grid, i, j, N)
          if (alive == 3 .or. (grid(i,j) == 1 .and. alive == 2)) then
            new_grid(i,j) = 1
          else
            new_grid(i,j) = 0
          end if
        end do
      end do
  
      grid(1:N,1:N) = new_grid
      call update_boundaries(grid, N)
  
      if (print_every == -1) then
        if (step == 4 .or. step == 20 .or. step == 40 .or. step == 80) then
          print *, ""
          print *, "Step", step, ": Alive =", sum(grid(1:N,1:N))
          call print_grid(grid(1:N,1:N))
        end if
      else if (print_every > 0) then
        if (mod(step, print_every) == 0) then
          print *, "Step", step, ": Alive =", sum(grid(1:N,1:N))
        end if
      end if
    end do
  
    call cpu_time(t1)
    total_time = t1 - t0
  
    print *
    print '(A)', "========================================"
    print '(A,F12.6)', "TOTAL_TIME_SEC: ", total_time
    print '(A,I0)',     "ALIVE_FINAL:    ", sum(grid(1:N,1:N))
    print '(A,I0)',     "GRID_SIZE:      ", N * N
    print '(A,I0)',     "TIMESTEPS:      ", STEPS
    print '(A)', "========================================"
  
    deallocate(grid, new_grid)
  
  contains
  
    integer function count_neighbors(g, i, j, n)
      integer, intent(in) :: n
      integer, intent(in) :: g(0:n+1,0:n+1)
      integer, intent(in) :: i, j
      count_neighbors = sum(g(i-1:i+1, j-1:j+1)) - g(i,j)
    end function count_neighbors
  
    subroutine update_boundaries(g, n)
      integer, intent(in) :: n
      integer, intent(inout) :: g(0:n+1,0:n+1)
  
      g(1:n,0)   = g(1:n,n)
      g(1:n,n+1) = g(1:n,1)
      g(0,1:n)   = g(n,1:n)
      g(n+1,1:n) = g(1,1:n)
  
      g(0,0)       = g(n,n)
      g(0,n+1)     = g(n,1)
      g(n+1,0)     = g(1,n)
      g(n+1,n+1)   = g(1,1)
    end subroutine update_boundaries
  
    subroutine print_grid(g)
      integer, intent(in) :: g(:,:)
      integer :: i, j
      do i = 1, size(g,1)
        do j = 1, size(g,2)
          write(*,'(A)', advance='no') merge('●', '○', g(i,j)==1)
        end do
        write(*,*)
      end do
      write(*,*)
    end subroutine print_grid
  
  end program Game_of_Life_Serial
