!===============================================================================
! MPI Latency and Bandwidth Microbenchmark
!===============================================================================
!
! DESCRIPTION:
!   Ping-pong benchmark to measure MPI communication parameters:
!   - t_s: startup latency (time for zero-byte message)
!   - t_w: per-byte transfer time (inverse of bandwidth)
!
! METHODOLOGY:
!   - Uses 2 MPI ranks in ping-pong pattern
!   - Tests message sizes from 4 bytes to 4 MB (powers of 2)
!   - 1000 iterations per size for statistical stability
!   - Reports round-trip time / 2 for one-way latency
!
! OUTPUT:
!   Writes to latency_results.txt:
!   - t_s estimate from smallest message size
!   - t_w estimate from linear fit of larger messages
!   - Per-size timing data
!
! USAGE:
!   mpirun -np 2 ./latency
!
! PERFORMANCE MODEL:
!   T(bytes) = t_s + bytes * t_w
!
!===============================================================================

program latency_measurement
  use mpi
  implicit none
  
  ! Latency measurement for Game of Life performance model
  ! Measures t_s (startup latency) and t_w (transfer time per word)
  ! 
  ! FIXED: Buffer allocation now ensures minimum 1 integer (4 bytes)
  ! to avoid zero-size sends for small message sizes

  integer, parameter :: max_power = 20
  integer :: rank, size, ierr, i, tag, msg_size, count
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
  extract_params = .true.
  
  if (rank == 0) then
    open(unit=10, file=filename, status='replace')
    write(10, '(A)') '=========================================='
    write(10, '(A)') 'MPI Latency Microbenchmark Results'
    write(10, '(A)') 'Game of Life Performance Model Parameters'
    write(10, '(A)') '=========================================='
    write(10, '(A)') ''
    write(10, '(A)') 'Size(Bytes)  Count(ints)  AvgTime(s)  Bandwidth(GB/s)  t_s_est  t_w_est'
    write(10, '(A)') '----------------------------------------------------------------------'
    print *, '=========================================='
    print *, 'MPI Latency Measurement'
    print *, 'Game of Life Performance Model'
    print *, '=========================================='
    print *, ''
  end if

  num_trials = 1000
  tag = 0

  ! Initialize t_s and t_w
  t_s = 0.0d0
  t_w = 0.0d0

  do i = 0, max_power
    ! FIX: Ensure minimum 1 integer (4 bytes) to avoid zero-size messages
    ! msg_size is in bytes, count is in integers
    msg_size = 4 * (2**i)  ! Start at 4 bytes, double each iteration
    count = msg_size / 4    ! Number of integers to send
    
    allocate(buffer(count))

    ! Synchronize before timing
    call MPI_Barrier(MPI_COMM_WORLD, ierr)
    start_time = MPI_Wtime()

    do trial = 1, num_trials
      if (rank == 0) then
        call MPI_Send(buffer, count, MPI_INTEGER, partner0, tag, MPI_COMM_WORLD, ierr)
        call MPI_Recv(buffer, count, MPI_INTEGER, partner0, tag, MPI_COMM_WORLD, status, ierr)
      else
        call MPI_Recv(buffer, count, MPI_INTEGER, partner1, tag, MPI_COMM_WORLD, status, ierr)
        call MPI_Send(buffer, count, MPI_INTEGER, partner1, tag, MPI_COMM_WORLD, ierr)
      end if
    end do

    end_time = MPI_Wtime()
    elapsed_time = end_time - start_time
    avg_time = elapsed_time / (2.0d0 * num_trials)  ! Half round-trip time

    if (rank == 0) then
        bandwidth = (2.0d0 * msg_size) / (avg_time * 1.0d9)  ! GB/s
        
        ! Extract performance parameters
        ! t_s: startup latency from smallest message (4 bytes)
        if (msg_size == 4) then
            t_s = avg_time
        end if
        
        ! t_w: per-byte transfer time from large messages (>=1KB)
        if (msg_size >= 1024) then
            t_w = avg_time / dble(msg_size)
        end if
        
        write(10, '(I12, 2X, I10, 2X, E12.6, 2X, F10.4, 2X, E12.6, 2X, E12.6)') &
             msg_size, count, avg_time, bandwidth, t_s, t_w
    end if

    deallocate(buffer)
  end do

  if (rank == 0) then
    write(10, '(A)') ''
    write(10, '(A)') '=========================================='
    write(10, '(A)') 'Estimated Performance Model Parameters'
    write(10, '(A)') '=========================================='
    write(10, '(A,E12.6,A)') 't_s (startup latency):  ', t_s, ' seconds'
    write(10, '(A,E12.6,A)') 't_w (per-byte transfer):', t_w, ' seconds/byte'
    write(10, '(A)') ''
    write(10, '(A)') 'Use these in performance model:'
    write(10, '(A,E12.6)') 'parameter :: t_s = ', t_s
    write(10, '(A,E12.6)') 'parameter :: t_w = ', t_w
    close(10)
    
    print *, ''
    print *, '=========================================='
    print *, 'Results written to latency_results.txt'
    print *, '=========================================='
    print *, ''
    print *, 'Estimated Performance Parameters:'
    print *, '=================================='
    write(*,'(A,E12.6,A)') 't_s (startup latency):  ', t_s, ' seconds'
    write(*,'(A,E12.6,A)') 't_w (transfer time):    ', t_w, ' seconds/byte'
    print *, ''
    print *, 'Update performance model with:'
    write(*,'(A,E12.6)') 'double precision, parameter :: t_s = ', t_s
    write(*,'(A,E12.6)') 'double precision, parameter :: t_w = ', t_w
    print *, ''
  end if

  call MPI_Finalize(ierr)
end program latency_measurement
