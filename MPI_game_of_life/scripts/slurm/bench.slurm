#!/bin/bash
#SBATCH --job-name=gol-bench
#SBATCH --output=gol-bench-%j.out
#SBATCH --time=00:15:00
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread

set -euo pipefail

module purge
module load ohpc || { echo "ERROR: failed to load module ohpc"; exit 1; }
module load gnu13/13.2.0 || { echo "ERROR: failed to load module gnu13/13.2.0"; exit 1; }
module load openmpi5/5.0.5 || { echo "ERROR: failed to load module openmpi5/5.0.5"; exit 1; }
export OMP_NUM_THREADS=1
export USE_SRUN=0

cd "$SLURM_SUBMIT_DIR"

bash scripts/build.sh
bash scripts/bench.sh
