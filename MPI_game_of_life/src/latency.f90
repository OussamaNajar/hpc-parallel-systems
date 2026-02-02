program latency_measurement
  use mpi
  implicit none
  
  ! Latency measurement for Game of Life performance model
  ! Measures t_s (startup latency) and t_w (transfer time per word)

  integer, parameter :: max_power = 20  ! Reduced for faster execution
  integer :: rank, size, ierr, i, tag, msg_size
  integer :: num_trials, trial
  integer, allocatable :: buffer(:)
  double precision :: start_time, end_time, elapsed_time, avg_time
  double precision :: bandwidth, t_s, t_w
  integer, parameter :: partner0 = 1, partner1 = 0
  integer :: status(MPI_STATUS_SIZE)
  character(len=100) :: filename
  logical :: extract_params

  call MPI_Init(ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, size, ierr)

  if (size /= 2) then
    if (rank == 0) print *, 'This program requires exactly 2 MPI tasks.'
    call MPI_Finalize(ierr)
    stop
  end if

  filename = 'latency_results.txt'
  extract_params = .true.  ! Extract t_s and t_w for performance model
  
  if (rank == 0) then
    open(unit=10, file=filename, status='replace')
    write(10, '(A)') 'Size(Bytes)  AvgTime(s)  Bandwidth(GB/s)  t_s_estimate  t_w_estimate'
    print *, 'MPI Latency Measurement for Game of Life Performance Model'
    print *, '==========================================================='
  end if

  num_trials = 1000  ! More trials for better accuracy
  tag = 0

  do i = 0, max_power
    msg_size = 2**i
    allocate(buffer(msg_size/4))  ! each INTEGER*4 => bytes

    ! Synchronize before timing
    call MPI_Barrier(MPI_COMM_WORLD, ierr)
    start_time = MPI_Wtime()

    do trial = 1, num_trials
      if (rank == 0) then
        call MPI_Send(buffer, msg_size/4, MPI_INTEGER, partner0, tag, MPI_COMM_WORLD, ierr)
        call MPI_Recv(buffer, msg_size/4, MPI_INTEGER, partner0, tag, MPI_COMM_WORLD, status, ierr)
      else
        call MPI_Recv(buffer, msg_size/4, MPI_INTEGER, partner1, tag, MPI_COMM_WORLD, status, ierr)
        call MPI_Send(buffer, msg_size/4, MPI_INTEGER, partner1, tag, MPI_COMM_WORLD, ierr)
      end if
    end do

    end_time = MPI_Wtime()
    elapsed_time = end_time - start_time
    avg_time = elapsed_time / (2.0d0 * num_trials)  ! Round-trip time divided by 2

    if (rank == 0) then
        bandwidth = (2.0d0 * msg_size) / (avg_time * 1.0d9)  ! GB/s
        
        ! Extract performance 
        if (msg_size == 1) then
            t_s = avg_time  ! Latency for 1-byte message ≈ startup time
        end if
        if (msg_size >= 1024) then
            t_w = avg_time / msg_size  ! Time per byte for large messages
        end if
        
        write(10, '(I12, 2X, E12.6, 2X, F10.4, 2X, E12.6, 2X, E12.6)') &
             msg_size, avg_time, bandwidth, t_s, t_w
    end if

    deallocate(buffer)
  end do

  if (rank == 0) then
    close(10)
    print *, ''
    print *, 'Results written to latency_results.txt'
    print *, ''
    print *, 'Estimated Performance Parameters:'
    print *, '================================'
    write(*,'(A,E12.6,A)') 't_s (startup latency):  ', t_s, ' seconds'
    write(*,'(A,E12.6,A)') 't_w (transfer time):    ', t_w, ' seconds/byte'
    print *, ''
    print *, 'Update these values in performance.f90:'
    write(*,'(A,E12.6)') 'double precision, parameter :: t_s = ', t_s
    write(*,'(A,E12.6)') 'double precision, parameter :: t_w = ', t_w
  end if

  call MPI_Finalize(ierr)
end program latency_measurement