#!/bin/bash

# ============================================================================
# MPI Game of Life Benchmark Suite - FIXED VERSION
# Includes: Serial baseline, MPI scaling, AND microbenchmarks
# ============================================================================

echo "============================================" > benchmark_results.txt
echo "MPI Game of Life Benchmark Suite" >> benchmark_results.txt
echo "============================================" >> benchmark_results.txt
echo "" >> benchmark_results.txt

echo "Machine Specs:" >> benchmark_results.txt
echo "==============" >> benchmark_results.txt
sysctl -n machdep.cpu.brand_string >> benchmark_results.txt
echo "Cores: $(sysctl -n hw.ncpu)" >> benchmark_results.txt
echo "RAM: $(echo "$(sysctl -n hw.memsize) / 1073741824" | bc) GB" >> benchmark_results.txt
sw_vers >> benchmark_results.txt
echo "" >> benchmark_results.txt

# ============================================================================
# PART 1: SERIAL BASELINE
# ============================================================================
echo "=== SERIAL BASELINE ===" | tee -a benchmark_results.txt
for i in 1 2 3; do
  echo "Run $i:" | tee -a benchmark_results.txt
  ./bin/serial 2048 2048 300 0 2>&1 | tee -a benchmark_results.txt
  echo "" >> benchmark_results.txt
done

# ============================================================================
# PART 2: MPI ROW DECOMPOSITION
# ============================================================================
for np in 2 4 8; do
  echo "=== ROW np=$np ===" | tee -a benchmark_results.txt
  for i in 1 2 3; do
    echo "Run $i:" | tee -a benchmark_results.txt
    mpirun -np $np ./bin/row 2048 2048 300 0 2>&1 | tee -a benchmark_results.txt
    echo "" >> benchmark_results.txt
  done
done

# ============================================================================
# PART 3: MPI COLUMN DECOMPOSITION
# ============================================================================
for np in 2 4 8; do
  echo "=== COLUMN np=$np ===" | tee -a benchmark_results.txt
  for i in 1 2 3; do
    echo "Run $i:" | tee -a benchmark_results.txt
    mpirun -np $np ./bin/column 2048 2048 300 0 2>&1 | tee -a benchmark_results.txt
    echo "" >> benchmark_results.txt
  done
done

# ============================================================================
# PART 4: MICROBENCHMARKS (NEW - CRITICAL FOR RESUME)
# ============================================================================
echo "" | tee -a benchmark_results.txt
echo "============================================" | tee -a benchmark_results.txt
echo "MICROBENCHMARKS FOR PERFORMANCE MODELING" | tee -a benchmark_results.txt
echo "============================================" | tee -a benchmark_results.txt
echo "" | tee -a benchmark_results.txt

# Computation time microbenchmark
echo "=== COMPUTATION TIME MICROBENCHMARK ===" | tee -a benchmark_results.txt
if [ -f ./bin/computation_time ]; then
  ./bin/computation_time 2>&1 | tee -a benchmark_results.txt
  echo "" >> benchmark_results.txt
  # Also append the detailed results file
  if [ -f computation_results.txt ]; then
    echo "--- Computation Results Detail ---" >> benchmark_results.txt
    cat computation_results.txt >> benchmark_results.txt
    echo "" >> benchmark_results.txt
  fi
else
  echo "WARNING: computation_time binary not found. Skipping." | tee -a benchmark_results.txt
fi

# MPI latency microbenchmark
echo "=== MPI LATENCY MICROBENCHMARK ===" | tee -a benchmark_results.txt
if [ -f ./bin/latency ]; then
  mpirun -np 2 ./bin/latency 2>&1 | tee -a benchmark_results.txt
  echo "" >> benchmark_results.txt
  # Also append the detailed results file
  if [ -f latency_results.txt ]; then
    echo "--- Latency Results Detail ---" >> benchmark_results.txt
    cat latency_results.txt >> benchmark_results.txt
    echo "" >> benchmark_results.txt
  fi
else
  echo "WARNING: latency binary not found. Skipping." | tee -a benchmark_results.txt
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo "" | tee -a benchmark_results.txt
echo "============================================" | tee -a benchmark_results.txt
echo "✅ ALL BENCHMARKS COMPLETE" | tee -a benchmark_results.txt
echo "============================================" | tee -a benchmark_results.txt
echo "" | tee -a benchmark_results.txt
echo "Results saved in:" | tee -a benchmark_results.txt
echo "  - benchmark_results.txt (main output)" | tee -a benchmark_results.txt
echo "  - latency_results.txt (microbench detail)" | tee -a benchmark_results.txt
echo "  - computation_results.txt (microbench detail)" | tee -a benchmark_results.txt
echo "" | tee -a benchmark_results.txt
echo "Use these files to:" | tee -a benchmark_results.txt
echo "  1. Validate scaling results" | tee -a benchmark_results.txt
echo "  2. Extract t_s, t_w, t_c for performance model" | tee -a benchmark_results.txt
echo "  3. Demonstrate complete benchmarking methodology" | tee -a benchmark_results.txt
echo "============================================" | tee -a benchmark_results.txt