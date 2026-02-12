#!/bin/bash
#SBATCH --job-name=game_of_life
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --time=00:10:00
#SBATCH --output=game_output.txt

set -euo pipefail

echo "Starting Game of Life simulation"
echo "Date: $(date)"
echo "SLURM_NTASKS=${SLURM_NTASKS:-4}"

# Load modules (adjust for your cluster)
module load gcc
module load openmpi

# Run from project root regardless of submission location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo ""
echo "=== Building ==="
make -f scripts/Makefile clean
make -f scripts/Makefile all

NP="${SLURM_NTASKS:-4}"

echo ""
echo "=== Running Serial Version ==="
./bin/serial

echo ""
echo "=== Running Column Decomposition ==="
mpirun -np "$NP" ./bin/column

echo ""
echo "=== Running Row Decomposition ==="
mpirun -np "$NP" ./bin/row

echo ""
echo "=== Running MPI MEGA Version ==="
mpirun -np "$NP" ./bin/mpi_mega

echo ""
echo "=== Running MPI TERA Version ==="
mpirun -np "$NP" ./bin/mpi_tera

echo ""
echo "=== Measuring Computation Time ==="
./bin/computation_time

echo ""
echo "=== Measuring Latency Parameters ==="
mpirun -np 2 ./bin/latency

echo ""
echo "All simulations completed!"
echo "Job finished: $(date)"
