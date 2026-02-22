#!/bin/bash
#SBATCH --job-name=lat2
#SBATCH --output=lat2-%j.out
#SBATCH --time=00:05:00
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --hint=nomultithread

set -euo pipefail

module purge
module load ohpc || { echo "ERROR: failed to load module ohpc"; exit 1; }
module load gnu13/13.2.0 || { echo "ERROR: failed to load module gnu13/13.2.0"; exit 1; }
module load openmpi5/5.0.5 || { echo "ERROR: failed to load module openmpi5/5.0.5"; exit 1; }
export OMP_NUM_THREADS=1

cd "$SLURM_SUBMIT_DIR"

bash scripts/build.sh

export BENCH_PLATFORM=hummingbird
export BENCH_TAG="latency2_job${SLURM_JOB_ID}"
export MAX_NP=2
export NP_LIST=2
export REPS=1
export USE_SRUN=0
export BENCH_MODE=latency

bash scripts/bench.sh
