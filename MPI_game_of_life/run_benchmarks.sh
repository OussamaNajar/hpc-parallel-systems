#!/bin/bash

echo "Machine Specs:" > benchmark_results.txt
sysctl -n machdep.cpu.brand_string >> benchmark_results.txt
echo "Cores: $(sysctl -n hw.ncpu)" >> benchmark_results.txt
echo "RAM: $(echo "$(sysctl -n hw.memsize) / 1073741824" | bc) GB" >> benchmark_results.txt
sw_vers >> benchmark_results.txt
echo "" >> benchmark_results.txt

# SERIAL BASELINE
echo "=== SERIAL BASELINE ===" | tee -a benchmark_results.txt
for i in 1 2 3; do
  echo "Run $i:" | tee -a benchmark_results.txt
  ./bin/serial 2048 2048 300 0 2>&1 | tee -a benchmark_results.txt
  echo "" >> benchmark_results.txt
done

# ROW DECOMPOSITION
for np in 2 4 8; do
  echo "=== ROW np=$np ===" | tee -a benchmark_results.txt
  for i in 1 2 3; do
    echo "Run $i:" | tee -a benchmark_results.txt
    mpirun -np $np ./bin/row 2048 2048 300 0 2>&1 | tee -a benchmark_results.txt
    echo "" >> benchmark_results.txt
  done
done

# COLUMN DECOMPOSITION
for np in 2 4 8; do
  echo "=== COLUMN np=$np ===" | tee -a benchmark_results.txt
  for i in 1 2 3; do
    echo "Run $i:" | tee -a benchmark_results.txt
    mpirun -np $np ./bin/column 2048 2048 300 0 2>&1 | tee -a benchmark_results.txt
    echo "" >> benchmark_results.txt
  done
done

echo ""
echo "✅ Benchmarks complete! Results in benchmark_results.txt"
