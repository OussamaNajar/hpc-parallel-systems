#!/bin/bash
#SBATCH --job-name=gol-sanity
#SBATCH --output=gol-sanity-%j.out
#SBATCH --time=00:05:00
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

cd "$SLURM_SUBMIT_DIR"

# small sanity parameters
export GRID_X=256
export GRID_Y=256
export STEPS=50
export REPS=1
export BENCH_PLATFORM=hummingbird
export BENCH_TAG="sanity_job${SLURM_JOB_ID}"
export MAX_NP="${SLURM_NTASKS}"
export USE_SRUN=0

bash scripts/build.sh
bash scripts/bench.sh
