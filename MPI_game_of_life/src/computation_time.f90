!===============================================================================
! Computation Time Microbenchmark (t_c measurement)
!===============================================================================
!
! DESCRIPTION:
!   Measures the per-cell update time (t_c) for the Game of Life stencil.
!   This parameter is used in the analytical performance model.
!
! METHODOLOGY:
!   - Allocates a small grid (20x20) with random initial state
!   - Runs 10,000 iterations of the update kernel
!   - Reports time per cell-update
!
! OUTPUT:
!   Writes to computation_results.txt:
!   - Total time for all iterations
!   - t_c: time per cell update (seconds)
!
! USAGE:
!   ./computation_time
!
! TYPICAL VALUES:
!   - t_c ~ 7.67 ns on Intel Xeon E5-2650 v4
!
!===============================================================================

program computation_time
  implicit none

  ! Computation timing for Game of Life performance model
  ! Estimates t_c (per-cell update time) via repeated executions
  ! 
  ! NOTE: operations_per_cell is a modeling assumption, not an exact count
  ! Used to normalize timing to a "per-operation" basis for performance model
  
  integer, parameter :: rows = 10, cols = 11
  integer, parameter :: rand_rows = 20, rand_cols = 20
  integer, parameter :: timing_iterations = 10000
  
  integer :: i, j, iter
  integer, dimension(rows, cols) :: nyxarray, output_array
  integer, dimension(rows * cols) :: data
  integer, dimension(rand_rows, rand_cols) :: random_input, random_output
  real :: r
  
  ! Timing variables
  real :: start_time, end_time, elapsed_time
  real :: operations_per_cell, total_operations, t_c, t_c_per_cell
  
  data = (/ &
    0,1,0,1,0,0,0,0,0,0,0, &
    1,0,1,0,0,0,0,0,0,0,1, &
    0,0,0,1,1,0,1,1,0,0,1, &
    0,0,0,1,0,0,0,1,0,0,0, &
    0,0,0,0,0,0,0,0,0,0,0, &
    0,1,0,1,0,0,0,1,0,1,0, &
    0,0,1,0,0,1,0,0,1,0,0, &
    1,0,0,1,0,0,0,1,0,0,0, &
    1,0,0,0,0,1,0,0,1,0,1, &
    0,0,0,0,0,0,0,1,0,1,0 /)

  ! Fill nyxarray row-by-row using reshape
  nyxarray = reshape(data, shape=[rows, cols], order=[2,1])

  print *, "=========================================="
  print *, "Computation Time Microbenchmark"
  print *, "Game of Life t_c Estimation"
  print *, "=========================================="
  print *, ""

  ! Apply update rule using periodic boundaries
  call update_array(nyxarray, output_array, rows, cols)

  ! Print original and updated arrays
  print *, "Original nyxarray:"
  call print_array(nyxarray, rows, cols)

  print *, "Updated output_array:"
  call print_array(output_array, rows, cols)
  print *, ""

  ! Generate random matrix for timing
  do i = 1, rand_rows
      do j = 1, rand_cols
        call random_number(r)
        if (r < 0.5) then
          random_input(i,j) = 0
        else
          random_input(i,j) = 1
        end if
      end do
  end do
  
  print *, "Timing Computation Performance..."
  print *, "================================"
  write(*,'(A,I0,A,I0)') "Grid size: ", rand_rows, " x ", rand_cols
  write(*,'(A,I0)') "Iterations: ", timing_iterations
  print *, ""
  
  ! Time the computation
  call cpu_time(start_time)
  
  do iter = 1, timing_iterations
      call update_array(random_input, random_output, rand_rows, rand_cols)
  end do
  
  call cpu_time(end_time)
  elapsed_time = end_time - start_time
  
  ! Calculate timing metrics
  ! NOTE: operations_per_cell = 10.0 is a modeling assumption
  ! (8 neighbor reads + 1 sum + 1 write ~= 10 operations)
  ! This is used to normalize to "operations" for performance model
  operations_per_cell = 10.0
  total_operations = timing_iterations * rand_rows * rand_cols * operations_per_cell
  t_c = elapsed_time / total_operations  ! Time per operation
  t_c_per_cell = elapsed_time / (timing_iterations * rand_rows * rand_cols)  ! Time per cell
  
  print *, "Timing Results:"
  print *, "==============="
  write(*,'(A,F8.4,A)') "Total time: ", elapsed_time, " seconds"
  write(*,'(A,E12.6)') "Total cell updates: ", real(timing_iterations * rand_rows * rand_cols)
  write(*,'(A,E12.6,A)') "t_c (per-cell update time): ", t_c_per_cell, " seconds"
  write(*,'(A,E12.6,A)') "t_c (per-operation, model): ", t_c, " seconds"
  print *, ""
  print *, "NOTE: 'per-operation' uses modeling assumption of ~10 ops/cell"
  print *, "      For performance model, use per-cell time directly"
  print *, ""
  
  ! Write results to file
  open(unit=20, file='computation_results.txt', status='replace')
  write(20, '(A)') '=========================================='
  write(20, '(A)') 'Computation Time Microbenchmark Results'
  write(20, '(A)') 'Game of Life t_c Estimation'
  write(20, '(A)') '=========================================='
  write(20, '(A)') ''
  write(20, '(A,I0,A,I0)') 'Grid size: ', rand_rows, ' x ', rand_cols
  write(20, '(A,I0)') 'Iterations: ', timing_iterations
  write(20, '(A,F8.4,A)') 'Total time: ', elapsed_time, ' seconds'
  write(20, '(A)') ''
  write(20, '(A,E12.6,A)') 't_c (per-cell update): ', t_c_per_cell, ' seconds'
  write(20, '(A,E12.6,A)') 't_c (per-op, model):   ', t_c, ' seconds'
  write(20, '(A)') ''
  write(20, '(A)') 'Use in performance model:'
  write(20, '(A,E12.6)') 'parameter :: t_c = ', t_c_per_cell
  close(20)
  
  print *, "Results written to computation_results.txt"
  print *, ""
  print *, "Update performance model with:"
  write(*,'(A,E12.6)') "double precision, parameter :: t_c = ", t_c_per_cell
  print *, ""
  
  ! Show sample output
  call update_array(random_input, random_output, rand_rows, rand_cols)
  
  print *, "Sample Random Input (first 5x10):"
  call print_array_section(random_input, 5, 10, rand_rows, rand_cols)
  print *, "Sample Random Output (first 5x10):"
  call print_array_section(random_output, 5, 10, rand_rows, rand_cols)

contains

subroutine update_array(input, output, r, c)
  integer, intent(in) :: r, c
  integer, dimension(r, c), intent(in) :: input
  integer, dimension(r, c), intent(out) :: output
  integer :: i, j, di, dj, ni, nj, sum
  
  do i = 1, r
      do j = 1, c
        sum = 0
        do di = -1, 1
          do dj = -1, 1
            if (di == 0 .and. dj == 0) cycle
            ni = modulo(i + di - 1, r) + 1
            nj = modulo(j + dj - 1, c) + 1
            sum = sum + input(ni, nj)
          end do
        end do
    
        ! Apply Game of Life rules 
        if (sum == 3) then
          output(i, j) = 1                 
        else if (sum == 2) then  
          output(i, j) = input(i, j)        
        else
          output(i, j) = 0                
        end if
      end do
    end do
end subroutine update_array

subroutine print_array(arr, r, c)
  integer, intent(in) :: r, c
  integer, dimension(r, c), intent(in) :: arr
  integer :: i, j
  do i = 1, r
    do j = 1, c
      write(*,'(I1)', advance='no') arr(i,j)
    end do
    print *
  end do
end subroutine print_array

subroutine print_array_section(arr, max_r, max_c, r, c)
  integer, intent(in) :: r, c, max_r, max_c
  integer, dimension(r, c), intent(in) :: arr
  integer :: i, j, print_r, print_c
  
  print_r = min(max_r, r)
  print_c = min(max_c, c)
  
  do i = 1, print_r
    do j = 1, print_c
      write(*,'(I1)', advance='no') arr(i,j)
    end do
    print *
  end do
end subroutine print_array_section

end program computation_time
