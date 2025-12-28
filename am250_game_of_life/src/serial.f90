program Game_of_Life_Serial
    implicit none
    
    ! Step 2: Serial version 
    
    
    integer, parameter :: N = 20, STEPS = 80
    integer :: grid(0:N+1,0:N+1), new_grid(1:N,1:N), step, i, j, alive
  
    ! Initialize 
    grid = 0
  
    ! Place glider pattern at top-left corner as specified in instructions
    grid(1,3) = 1
    grid(2,1) = 1   
    grid(2,3) = 1   
    grid(3,2) = 1   
    grid(3,3) = 1
  
    call update_boundaries(grid)
  
    print *, "=========================================="
    print *, "Serial Game of Life Reference"
    print *, "Grid: 20x20, Steps: 80"
    print *, "Pattern: Glider at top-left corner"
    print *, "=========================================="
    print *, ""
    print *, "Step 0: Alive =", sum(grid(1:N,1:N))
    call print_grid(grid(1:N,1:N))
  
    do step = 1, STEPS
      ! Update cell states based on neighbors
      do i = 1, N
        do j = 1, N
          alive = count_neighbors(grid, i, j)
          if (alive == 3 .or. (grid(i,j) == 1 .and. alive == 2)) then
            new_grid(i,j) = 1
          else
            new_grid(i,j) = 0
          end if
        end do
      end do
  
      ! Copy updated grid back
      grid(1:N,1:N) = new_grid
      call update_boundaries(grid)
  
      ! Print snapshots at key steps 
      if (step == 4 .or. step == 20 .or. step == 40 .or. step == 80) then
        print *, ""
        print *, "Step", step, ": Alive =", sum(grid(1:N,1:N))
        call print_grid(grid(1:N,1:N))
      end if
    end do
  
  contains
  
    integer function count_neighbors(g, i, j)
      integer, intent(in) :: g(0:N+1,0:N+1)
      integer, intent(in) :: i, j
      count_neighbors = sum(g(i-1:i+1, j-1:j+1)) - g(i,j)
    end function count_neighbors
  
    subroutine update_boundaries(g)
      integer, intent(inout) :: g(0:N+1,0:N+1)
  
      ! Periodic boundaries
      g(1:N,0)   = g(1:N,N)     ! Left ghost = right
      g(1:N,N+1) = g(1:N,1)     ! Right ghost = left
      g(0,1:N)   = g(N,1:N)     ! Top ghost = bottom
      g(N+1,1:N) = g(1,1:N)     ! Bottom ghost = top
  
      ! Corner cells
      g(0,0)       = g(N,N)
      g(0,N+1)     = g(N,1)
      g(N+1,0)     = g(1,N)
      g(N+1,N+1)   = g(1,1)
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