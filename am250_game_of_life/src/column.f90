program Column_Decomposition
    use mpi
    implicit none
    
    integer, parameter :: N = 20, STEPS = 80
    integer :: rank, nprocs, ierr, step, i, j, neighbors
    integer :: local_cols, left, right
    integer, allocatable :: grid(:,:), new_grid(:,:), global_data(:)
    integer, allocatable :: counts(:), displs(:)
    integer :: status(MPI_STATUS_SIZE)
    
    call MPI_Init(ierr)
    call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
    call MPI_Comm_size(MPI_COMM_WORLD, nprocs, ierr)
    
    ! Domain decomposition by columns (Fortran column-major friendly)
    local_cols = N / nprocs + merge(1, 0, rank < mod(N, nprocs))
    
    ! Allocate with ghost columns (0 and local_cols+1 are ghost)
    allocate(grid(0:N+1, 0:local_cols+1), new_grid(1:N, 1:local_cols))
    
    ! Initialize
    grid = 0
    if (rank == 0) then
        ! Glider
        grid(1,3) = 1   
        grid(2,1) = 1  
        grid(2,3) = 1  
        grid(3,2) = 1   
        grid(3,3) = 1  
    end if
    
    ! Setup for GATHERV
    allocate(counts(nprocs), displs(nprocs), global_data(merge(N*N, 1, rank==0)))
    do i = 1, nprocs
        counts(i) = N * (N / nprocs + merge(1, 0, i-1 < mod(N, nprocs)))
        displs(i) = merge(0, displs(i-1) + counts(i-1), i==1)
    end do
    
    !  periodic boundaries
    left = mod(rank - 1 + nprocs, nprocs)
    right = mod(rank + 1, nprocs)
    
    ! Print initial state
    call print_step(0)
    
    do step = 1, STEPS
        ! Exchange ghost columns with neighbors
        call MPI_Sendrecv(grid(1:N,1), N, MPI_INTEGER, left, 0, &
                         grid(1:N,local_cols+1), N, MPI_INTEGER, right, 0, &
                         MPI_COMM_WORLD, status, ierr)
        call MPI_Sendrecv(grid(1:N,local_cols), N, MPI_INTEGER, right, 1, &
                         grid(1:N,0), N, MPI_INTEGER, left, 1, &
                         MPI_COMM_WORLD, status, ierr)
        
        ! Periodic boundaries for rows
        grid(0,:) = grid(N,:)
        grid(N+1,:) = grid(1,:)
        
        ! Apply Game of Life rules
        do i = 1, N
            do j = 1, local_cols
                neighbors = sum(grid(i-1:i+1,j-1:j+1)) - grid(i,j)
                new_grid(i,j) = merge(1, 0, neighbors == 3 .or. &
                                           (grid(i,j)==1 .and. neighbors==2))
            end do
        end do
        grid(1:N,1:local_cols) = new_grid
        
        ! Print at specified steps
        if (step==4 .or. step==20 .or. step==40 .or. step==80) then
            call print_step(step)
        end if
    end do
    
    deallocate(grid, new_grid, counts, displs, global_data)
    call MPI_Finalize(ierr)

contains

    subroutine print_step(step_num)
        integer, intent(in) :: step_num
        integer :: local_data(N * local_cols), k
        
        ! Pack local data (column-major)
        k = 1
        do j = 1, local_cols
            do i = 1, N
                local_data(k) = grid(i,j)
                k = k + 1
            end do
        end do
        
        ! Gather all data
        call MPI_Gatherv(local_data, N*local_cols, MPI_INTEGER, &
                        global_data, counts, displs, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
        
        if (rank == 0) then
            if (step_num == 0) then
                write(*,*) "Initial configuration (step 0) - Column Decomposition:"
            else
                write(*,*) ""
                write(*,'(A,I0,A)') " Grid at step ", step_num, " (Column):"
            end if
            
            do i = 1, N
                do j = 1, N
                    write(*,'(A)', advance='no') merge('●', '○', global_data((j-1)*N+i)==1)
                end do
                write(*,*)
            end do
            write(*,*)
            
            if (step_num > 0) then
                write(*,'(A,I0,A,I0)') " Step ", step_num, " : Total alive cells = ", sum(global_data)
            end if
        end if
    end subroutine

end program Column_Decomposition