program Column_Decomposition
    use mpi
    implicit none
    
    integer :: N, STEPS, print_every, nargs
    character(len=64) :: arg
    integer :: rank, nprocs, ierr, step, i, j, neighbors
    integer :: local_cols, left, right
    integer, allocatable :: grid(:,:), new_grid(:,:), global_data(:)
    integer, allocatable :: counts(:), displs(:)
    integer :: status(MPI_STATUS_SIZE)
    
    double precision :: t0, t1, total_time, comm_time, comp_time
    double precision :: tcomm0, tcomm1
    
    call MPI_Init(ierr)
    call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
    call MPI_Comm_size(MPI_COMM_WORLD, nprocs, ierr)
    
    N = 20
    STEPS = 80
    print_every = -1
    
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
    
    local_cols = N / nprocs + merge(1, 0, rank < mod(N, nprocs))
    
    allocate(grid(0:N+1, 0:local_cols+1), new_grid(1:N, 1:local_cols))
    
    grid = 0
    if (rank == 0 .and. N >= 3) then
        grid(1,3) = 1   
        grid(2,1) = 1  
        grid(2,3) = 1  
        grid(3,2) = 1   
        grid(3,3) = 1  
    end if
    
    allocate(counts(nprocs), displs(nprocs), global_data(merge(N*N, 1, rank==0)))
    do i = 1, nprocs
        counts(i) = N * (N / nprocs + merge(1, 0, i-1 < mod(N, nprocs)))
        displs(i) = merge(0, displs(i-1) + counts(i-1), i==1)
    end do
    
    left = mod(rank - 1 + nprocs, nprocs)
    right = mod(rank + 1, nprocs)
    
    if (rank == 0) then
      if (print_every == -1) then
        ! Don't print header here - print_step will handle it
      else
        write(*,'(A)') "=========================================="
        write(*,'(A,I0,A,I0,A,I0)') "Column Decomposition: ", N, "x", N, ", Steps: ", STEPS
        write(*,'(A,I0)') "MPI Ranks: ", nprocs
        write(*,'(A)') "=========================================="
      end if
    end if
    
    if (print_every /= 0) then
      call print_step(0)
    end if
    
    call MPI_Barrier(MPI_COMM_WORLD, ierr)
    t0 = MPI_Wtime()
    comm_time = 0.0d0
    
    do step = 1, STEPS
        tcomm0 = MPI_Wtime()
        
        call MPI_Sendrecv(grid(1:N,1), N, MPI_INTEGER, left, 0, &
                         grid(1:N,local_cols+1), N, MPI_INTEGER, right, 0, &
                         MPI_COMM_WORLD, status, ierr)
        call MPI_Sendrecv(grid(1:N,local_cols), N, MPI_INTEGER, right, 1, &
                         grid(1:N,0), N, MPI_INTEGER, left, 1, &
                         MPI_COMM_WORLD, status, ierr)
        
        tcomm1 = MPI_Wtime()
        comm_time = comm_time + (tcomm1 - tcomm0)
        
        grid(0,:) = grid(N,:)
        grid(N+1,:) = grid(1,:)
        
        do i = 1, N
            do j = 1, local_cols
                neighbors = sum(grid(i-1:i+1,j-1:j+1)) - grid(i,j)
                new_grid(i,j) = merge(1, 0, neighbors == 3 .or. &
                                           (grid(i,j)==1 .and. neighbors==2))
            end do
        end do
        grid(1:N,1:local_cols) = new_grid
        
        if (print_every == -1) then
          if (step==4 .or. step==20 .or. step==40 .or. step==80) then
            call print_step(step)
          end if
        else if (print_every > 0) then
          if (mod(step, print_every) == 0) then
            call print_step(step)
          end if
        end if
    end do
    
    call MPI_Barrier(MPI_COMM_WORLD, ierr)
    t1 = MPI_Wtime()
    
    total_time = t1 - t0
    comp_time = total_time - comm_time
    
    ! All ranks must participate in Gatherv
    call count_alive_cells()
    
    if (rank == 0) then
      write(*,*)
      write(*,'(A)') "========================================"
      write(*,'(A,F12.6)') "TOTAL_TIME_SEC: ", total_time
      write(*,'(A,F12.6)') "COMM_TIME_SEC:  ", comm_time
      write(*,'(A,F12.6)') "COMP_TIME_SEC:  ", comp_time
      if (total_time > 0.0d0) then
        write(*,'(A,F8.2,A)') "COMM_FRACTION:  ", (comm_time/total_time)*100.0d0, "%"
      end if
      write(*,'(A,I0)')     "GRID_SIZE:      ", N * N
      write(*,'(A,I0)')     "TIMESTEPS:      ", STEPS
      write(*,'(A,I0)')     "MPI_RANKS:      ", nprocs
      write(*,'(A)') "========================================"
    end if
    
    deallocate(grid, new_grid, counts, displs, global_data)
    call MPI_Finalize(ierr)

contains

    subroutine print_step(step_num)
        integer, intent(in) :: step_num
        integer :: local_data(N * local_cols), k
        
        k = 1
        do j = 1, local_cols
            do i = 1, N
                local_data(k) = grid(i,j)
                k = k + 1
            end do
        end do
        
        call MPI_Gatherv(local_data, N*local_cols, MPI_INTEGER, &
                        global_data, counts, displs, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
        
        if (rank == 0) then
            if (step_num == 0) then
                if (print_every == -1) then
                  write(*,*) "Initial configuration (step 0) - Column Decomposition:"
                end if
            else
                write(*,*) ""
                write(*,'(A,I0,A)') " Grid at step ", step_num, " (Column):"
            end if
            
            if (N <= 50 .or. print_every == -1) then
              do i = 1, N
                  do j = 1, N
                      write(*,'(A)', advance='no') merge('●', '○', global_data((j-1)*N+i)==1)
                  end do
                  write(*,*)
              end do
              write(*,*)
            end if
            
            if (step_num > 0) then
                write(*,'(A,I0,A,I0)') " Step ", step_num, " : Total alive cells = ", sum(global_data)
            end if
        end if
    end subroutine

    subroutine count_alive_cells()
        integer :: local_data(N * local_cols), k
        
        k = 1
        do j = 1, local_cols
            do i = 1, N
                local_data(k) = grid(i,j)
                k = k + 1
            end do
        end do
        
        call MPI_Gatherv(local_data, N*local_cols, MPI_INTEGER, &
                        global_data, counts, displs, MPI_INTEGER, 0, MPI_COMM_WORLD, ierr)
        
        if (rank == 0) then
          write(*,'(A,I0)') "ALIVE_FINAL:    ", sum(global_data)
        end if
    end subroutine

end program Column_Decomposition
