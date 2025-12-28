program Game_of_Life_Tera_Virtual_Topology
    use mpi
    implicit none
    
    ! Step 7: TERA VERSION - Virtual topology with MPI_CART_CREATE and MPI_CART_SHIFT
    
    integer, parameter :: N = 20, STEPS = 80
    integer :: rank, nprocs, ierr, step, i, j, neighbors
    integer :: local_rows
    integer, allocatable :: grid(:,:), new_grid(:,:), global_data(:)
    integer, allocatable :: counts(:), displs(:)
    integer :: status(MPI_STATUS_SIZE)
    
    ! Virtual topology variables
    integer :: cart_comm, cart_rank
    integer :: dims(1), coords(1)
    logical :: periods(1), reorder
    integer :: top_neighbor, bottom_neighbor
    
    call MPI_Init(ierr)
    call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
    call MPI_Comm_size(MPI_COMM_WORLD, nprocs, ierr)
    
    ! TERA VERSION: Create 1D Cartesian topology for row decomposition
    dims(1) = nprocs
    periods(1) = .true.  ! Periodic boundaries
    reorder = .true.     ! Allow MPI to reorder ranks for optimization
    
    call MPI_Cart_create(MPI_COMM_WORLD, 1, dims, periods, reorder, cart_comm, ierr)
    call MPI_Comm_rank(cart_comm, cart_rank, ierr)
    call MPI_Cart_coords(cart_comm, cart_rank, 1, coords, ierr)
    
    ! TERA VERSION: Use MPI_CART_SHIFT to find neighbors automatically
    call MPI_Cart_shift(cart_comm, 0, 1, top_neighbor, bottom_neighbor, ierr)
    
    if (cart_rank == 0) then
        write(*,*) "TERA VERSION: Using MPI Virtual Topology"
        write(*,'(A,I0,A)') "Created 1D Cartesian communicator with ", nprocs, " processors"
        write(*,*) "Topology handles periodic boundaries automatically"
        write(*,*) ""
    end if
    
    ! Domain decomposition - flexible for any nprocs
    local_rows = N / nprocs + merge(1, 0, cart_rank < mod(N, nprocs))
    
    ! Allocate with ghost rows
    allocate(grid(0:local_rows+1, 0:N+1), new_grid(1:local_rows, 1:N))
    
    ! Initialize 
    grid = 0
    if (cart_rank == 0) then
        ! pattern 
        grid(1,3) = 1
        grid(2,1) = 1   
        grid(2,3) = 1   
        grid(3,2) = 1   
        grid(3,3) = 1
    end if
    
    ! Setup for GATHERV (use original communicator for collective operations)
    allocate(counts(nprocs), displs(nprocs), global_data(merge(N*N, 1, cart_rank==0)))
    do i = 1, nprocs
        counts(i) = N * (N / nprocs + merge(1, 0, i-1 < mod(N, nprocs)))
        displs(i) = merge(0, displs(i-1) + counts(i-1), i==1)
    end do
    
    ! Print initial state
    call print_step(0)
  
    do step = 1, STEPS
        ! Periodic boundaries for columns
        grid(:,0) = grid(:,N)
        grid(:,N+1) = grid(:,1)
        
    
        ! MPI_CART_SHIFT auto handles periodic boundaries!
        call MPI_Sendrecv(grid(1,:), N+2, MPI_INTEGER, top_neighbor, 0, &
                         grid(local_rows+1,:), N+2, MPI_INTEGER, bottom_neighbor, 0, &
                         cart_comm, status, ierr)
        call MPI_Sendrecv(grid(local_rows,:), N+2, MPI_INTEGER, bottom_neighbor, 1, &
                         grid(0,:), N+2, MPI_INTEGER, top_neighbor, 1, &
                         cart_comm, status, ierr)
        
        ! Apply  rules
        do i = 1, local_rows
            do j = 1, N
                neighbors = sum(grid(i-1:i+1,j-1:j+1)) - grid(i,j)
                new_grid(i,j) = merge(1, 0, neighbors == 3 .or. &
                                           (grid(i,j)==1 .and. neighbors==2))
            end do
        end do
        grid(1:local_rows,1:N) = new_grid
        
        ! Print at specified steps
        if (step==4 .or. step==20 .or. step==40 .or. step==80) then
            call print_step(step)
        end if
    end do
    
   
    call MPI_Comm_free(cart_comm, ierr)
    
    deallocate(grid, new_grid, counts, displs, global_data)
    call MPI_Finalize(ierr)

contains

    subroutine print_step(step_num)
        integer, intent(in) :: step_num
        integer :: local_data(N * local_rows), k
        
        ! Pack local data (row-major for row decomposition)
        k = 1
        do i = 1, local_rows
            do j = 1, N
                local_data(k) = grid(i,j)
                k = k + 1
            end do
        end do
        
        ! Gather all data 
        call MPI_Gatherv(local_data, N*local_rows, MPI_INTEGER, &
                        global_data, counts, displs, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
        
        if (cart_rank == 0) then
            if (step_num == 0) then
                write(*,*) "Initial configuration (step 0) - TERA VERSION (Virtual Topology):"
            else
                write(*,*) ""
                write(*,'(A,I0,A)') " Grid at step ", step_num, " : (Virtual Topology)"
            end if
            
            do i = 1, N
                do j = 1, N
                    write(*,'(A)', advance='no') merge('●', '○', global_data((i-1)*N+j)==1)
                end do
                write(*,*)
            end do
            write(*,*)
            
            if (step_num > 0) then
                write(*,'(A,I0,A,I0)') " Step ", step_num, " : Total alive cells = ", sum(global_data)
            end if
        end if
    end subroutine

end program Game_of_Life_Tera_Virtual_Topology