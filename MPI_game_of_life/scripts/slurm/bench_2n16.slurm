#!/bin/bash
#SBATCH --job-name=gol-2n16
#SBATCH --output=gol-2n16-%j.out
#SBATCH --time=00:15:00
#SBATCH --nodes=2
#SBATCH --ntasks=16
#SBATCH --cpus-per-task=1
#SBATCH --distribution=block:block
#SBATCH --hint=nomultithread

set -euo pipefail

module purge
module load ohpc || { echo "ERROR: failed to load module ohpc"; exit 1; }
module load gnu13/13.2.0 || { echo "ERROR: failed to load module gnu13/13.2.0"; exit 1; }
module load openmpi5/5.0.5 || { echo "ERROR: failed to load module openmpi5/5.0.5"; exit 1; }
export OMP_NUM_THREADS=1

cd "$SLURM_SUBMIT_DIR"

# Debug allocation
echo "SLURM_JOB_ID=${SLURM_JOB_ID}"
echo "SLURM_JOB_NODELIST=${SLURM_JOB_NODELIST}"
echo "SLURM_NNODES=${SLURM_NNODES}"
echo "SLURM_NTASKS=${SLURM_NTASKS}"
echo "PWD=$(pwd)"
echo "HOST=$(hostname)"

# Build only if needed (cache guard)
if [[ ! -x bin/row ]] || [[ -n "$(find src -name '*.f90' -newer bin/row 2>/dev/null)" ]]; then
  echo "[slurm] Rebuilding (sources changed or binaries missing)"
  bash scripts/build.sh
else
  echo "[slurm] Skipping build (binaries up to date)"
fi

# Verify executables exist
ls -l bin/serial bin/row bin/column bin/mpi_block bin/mpi_2d bin/latency bin/computation_time
test -x bin/row && test -x bin/column && test -x bin/mpi_block && test -x bin/mpi_2d

# Run suite using mpirun (not srun - avoids per-step pitfalls)
export BENCH_PLATFORM=hummingbird
export BENCH_TAG="job${SLURM_JOB_ID}"
export MAX_NP="${SLURM_NTASKS}"
export USE_SRUN=0
export BIND_FLAGS="--bind-to core --map-by core --report-bindings"

bash scripts/bench.sh

# ==========================================
# POST-RUN VALIDATION: Verify MPI Ranks == np
# ==========================================
RUN_DIR=$(ls -dt experiments/hummingbird/*job${SLURM_JOB_ID} 2>/dev/null | head -n 1 || true)
BENCH_TXT="${RUN_DIR}/results/bench.txt"

echo "[slurm] validating ranks in ${BENCH_TXT}"
if [[ -f "${BENCH_TXT}" ]]; then
  # Fail if any labeled np section contains "MPI Ranks: 1" for np>1
  if grep -E "np=(2|4|8|16|32)" "${BENCH_TXT}" >/dev/null 2>&1; then
    BROKEN_SECTIONS=$(grep -B5 "MPI Ranks:.*1$" "${BENCH_TXT}" | grep -E "np=(2|4|8|16|32)" || true)
    if [[ -n "${BROKEN_SECTIONS}" ]]; then
      echo "ERROR: bench.txt indicates MPI Ranks: 1 in a multi-rank section. INVALID RUN."
      echo "Broken sections:"
      echo "${BROKEN_SECTIONS}"
      exit 2
    fi
  fi
  echo "[slurm] validation PASSED: all multi-rank sections show correct rank counts"
else
  echo "ERROR: missing ${BENCH_TXT}"
  exit 2
fi

echo "[slurm] done"
