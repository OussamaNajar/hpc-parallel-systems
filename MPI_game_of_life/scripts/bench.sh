#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

# Current wall-clock timestamp in ISO-8601 format.
now_iso8601() {
  if date -Is >/dev/null 2>&1; then date -Is; else date "+%Y-%m-%dT%H:%M:%S%z"; fi
}

# Return success when the argument is a non-negative integer.
is_integer() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

# Normalize a whitespace-separated integer list: keep unique values and sort.
unique_sorted_ints() {
  echo "${1:-}" | tr ' ' '\n' | awk 'NF && $1 ~ /^[0-9]+$/ {a[$1]=1} END{for(k in a) print k}' | sort -n | tr '\n' ' ' | xargs
}

# -----------------------
# Platform + run identity
# -----------------------
platform="${BENCH_PLATFORM:-}"
if [[ -z "${platform}" ]]; then
  platform=$([[ -n "${SLURM_JOB_ID:-}" ]] && echo "hummingbird" || echo "local")
fi

default_tag="manual"
[[ -n "${SLURM_JOB_ID:-}" ]] && default_tag="job${SLURM_JOB_ID}"
tag="${1:-${BENCH_TAG:-${default_tag}}}"

run_id="$(date +%F)_${tag}"
run_dir="experiments/${platform}/${run_id}"
results_dir="${run_dir}/results"
mkdir -p "${results_dir}"

bench_file="${results_dir}/bench.txt"
latency_file="${results_dir}/latency.txt"
compute_file="${results_dir}/compute.txt"
stdout_file="${run_dir}/stdout.txt"
provenance_file="${run_dir}/provenance.txt"

: > "${bench_file}"
: > "${latency_file}"
: > "${compute_file}"
: > "${stdout_file}"

exec > >(tee -a "${stdout_file}") 2>&1

# -----------------------
# Tunables (env override)
# -----------------------
GRID_X="${GRID_X:-2048}"
GRID_Y="${GRID_Y:-2048}"
STEPS="${STEPS:-300}"
PRINT_EVERY="${PRINT_EVERY:-0}"
REPS="${REPS:-3}"
BENCH_MODE="${BENCH_MODE:-full}"   # full | microbench | latency

if [[ "${GRID_X}" != "${GRID_Y}" ]]; then
  echo "[bench] error: only square grids supported (GRID_X=${GRID_X}, GRID_Y=${GRID_Y})" >&2
  exit 2
fi

case "${BENCH_MODE}" in
  full|microbench|latency) ;;
  *)
    echo "[bench] error: invalid BENCH_MODE='${BENCH_MODE}' (expected full|microbench|latency)" >&2
    exit 2
    ;;
esac

# Candidate scaling list (filtered to <= MAX_NP)
NP_CAND_DEFAULT="1 2 4 8 16 32 64"
NP_CAND="${NP_LIST:-${NP_CAND_DEFAULT}}"

# Determine MAX_NP (priority: MAX_NP env > SLURM_NTASKS > 32)
MAX_NP="${MAX_NP:-}"
if [[ -z "${MAX_NP}" ]]; then
  if is_integer "${SLURM_NTASKS:-}"; then
    MAX_NP="${SLURM_NTASKS}"
  else
    MAX_NP="32"
  fi
fi
is_integer "${MAX_NP}" || MAX_NP="32"

# Build filtered NP_LIST (then dedupe/sort)
_np_tmp=""
for np in ${NP_CAND}; do
  is_integer "${np}" || continue
  (( np >= 1 )) || continue
  (( np <= MAX_NP )) || continue
  _np_tmp="${_np_tmp} ${np}"
done
NP_LIST="$(unique_sorted_ints "${_np_tmp}")"
if [[ -z "${NP_LIST}" ]]; then
  echo "[bench] error: NP_LIST empty after filtering (MAX_NP=${MAX_NP}, NP_CAND='${NP_CAND}')" >&2
  exit 2
fi

# Include SLURM_NTASKS if present and not already in list
if [[ -n "${SLURM_NTASKS:-}" ]] && is_integer "${SLURM_NTASKS}" && [[ "${SLURM_NTASKS}" -gt 0 ]]; then
  if ! echo " ${NP_LIST} " | grep -q " ${SLURM_NTASKS} "; then
    NP_LIST="${NP_LIST} ${SLURM_NTASKS}"
    NP_LIST="$(echo "${NP_LIST}" | tr ' ' '\n' | awk 'NF' | sort -n | uniq | tr '\n' ' ' | xargs)"
  fi
fi

# Launcher selection
USE_SRUN="${USE_SRUN:-0}"
MPIRUN_BIN="${MPIRUN:-mpirun}"

if [[ "${USE_SRUN}" == "1" ]] && command -v srun >/dev/null 2>&1; then
  LAUNCHER="srun"
else
  LAUNCHER="mpirun"
fi

# Binding flags for OpenMPI (applied to mpirun runs on cluster)
# Override via env: export BIND_FLAGS="--bind-to core --map-by core"
BIND_FLAGS="${BIND_FLAGS:---bind-to core --map-by core --report-bindings}"

echo "[bench] project_dir=${PROJECT_DIR}"
echo "[bench] run_dir=${run_dir}"
echo "[bench] platform=${platform}"
echo "[bench] run_id=${run_id}"
echo "[bench] grid=${GRID_X}x${GRID_Y} steps=${STEPS} reps=${REPS}"
echo "[bench] mode=${BENCH_MODE}"
echo "[bench] MAX_NP=${MAX_NP}"
echo "[bench] NP_LIST=${NP_LIST}"
echo "[bench] launcher=${LAUNCHER}"
echo "[bench] BIND_FLAGS=${BIND_FLAGS}"

# -----------------------
# Preconditions
# -----------------------
required_bins=()
case "${BENCH_MODE}" in
  full)
    required_bins=(bin/serial bin/row bin/column bin/mpi_block bin/mpi_2d bin/latency bin/computation_time)
    ;;
  microbench)
    required_bins=(bin/latency bin/computation_time)
    ;;
  latency)
    required_bins=(bin/latency)
    ;;
esac

for b in "${required_bins[@]}"; do
  if [[ ! -x "${b}" ]]; then
    echo "[bench] error: missing executable ${b}. Run: bash scripts/build.sh" >&2
    exit 1
  fi
done

# Absolute paths eliminate cwd ambiguity on remote ranks
SERIAL_EXE="${PROJECT_DIR}/bin/serial"
ROW_EXE="${PROJECT_DIR}/bin/row"
COL_EXE="${PROJECT_DIR}/bin/column"
BLOCK_EXE="${PROJECT_DIR}/bin/mpi_block"
MPI2D_EXE="${PROJECT_DIR}/bin/mpi_2d"
LAT_EXE="${PROJECT_DIR}/bin/latency"
COMP_EXE="${PROJECT_DIR}/bin/computation_time"

launcher_cmd() {
  local np="$1"; shift

  if [[ "${USE_SRUN:-0}" == "1" ]]; then
    # Some clusters require --mpi=pmix* to launch one MPI job via srun.
    # If srun is misconfigured, MPI applications can report rank count 1.
    local SRUN_MPI="${SRUN_MPI:-}"
    local srun_base=(srun)

    if [[ -n "${SRUN_MPI}" ]]; then
      srun_base+=(--mpi="${SRUN_MPI}")
    fi

    # Avoid srun warning when np < SLURM_NNODES
    if [[ -n "${SLURM_NNODES:-}" ]] && is_integer "${SLURM_NNODES}" && [[ "${SLURM_NNODES}" -gt 1 ]] && [[ "${np}" -lt "${SLURM_NNODES}" ]]; then
      "${srun_base[@]}" --nodes=1 -n "${np}" "$@"
    else
      "${srun_base[@]}" -n "${np}" "$@"
    fi
  else
    local cmd=("${MPIRUN_BIN}" "-np" "${np}")

    if [[ "${platform}" == "local" ]] || [[ "${ALLOW_OVERSUBSCRIBE:-0}" == "1" ]]; then
      # Only add --oversubscribe if mpirun supports it (OpenMPI-specific)
      if "${MPIRUN_BIN}" --help 2>&1 | grep -q "oversubscribe"; then
        cmd+=("--oversubscribe")
      fi
    else
      # Cluster runs: pin ranks to cores to reduce jitter and timing variance
      # Use BIND_FLAGS so the choice is centralized and recorded in provenance
      # shellcheck disable=SC2206
      cmd+=(${BIND_FLAGS})
    fi

    "${cmd[@]}" "$@"
  fi
}

# -----------------------
# Provenance snapshot
# -----------------------
{
  # Best effort commit hash. Keep "unavailable" when not in a git checkout.
  git_commit="unavailable"
  if command -v git >/dev/null 2>&1; then
    git_commit_candidate="$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || true)"
    if [[ -n "${git_commit_candidate}" ]]; then
      git_commit="${git_commit_candidate}"
    fi
  fi
  echo "git_commit=${git_commit}"
  echo "hostname=$(hostname 2>/dev/null || uname -n)"
  echo "date_is=$(now_iso8601)"
  echo "pwd=$(pwd)"
  echo "launcher=${LAUNCHER}"
  echo "USE_SRUN=${USE_SRUN}"
  echo "MPIRUN_BIN=${MPIRUN_BIN}"
  echo "BIND_FLAGS=${BIND_FLAGS}"
  echo "SRUN_MPI=${SRUN_MPI:-}"
  _mpirun_path=$(command -v "${MPIRUN_BIN}" 2>/dev/null || echo unavailable)
  echo "mpirun_path=${_mpirun_path}"
  echo "mpirun_version=$(${MPIRUN_BIN} --version 2>/dev/null | head -n 1 || echo unavailable)"
  echo "srun_path=$(command -v srun 2>/dev/null || echo unavailable)"
  echo "gfortran_path=$(command -v gfortran 2>/dev/null || echo unavailable)"
  echo "gfortran_version=$(gfortran --version 2>/dev/null | head -n 1 || echo unavailable)"
  echo "mpif90_path=$(command -v mpif90 2>/dev/null || echo unavailable)"
  echo "mpif90_version=$(mpif90 --version 2>/dev/null | head -n 1 || echo unavailable)"
  echo "GRID_X=${GRID_X}"
  echo "GRID_Y=${GRID_Y}"
  echo "STEPS=${STEPS}"
  echo "PRINT_EVERY=${PRINT_EVERY}"
  echo "REPS=${REPS}"
  echo "MAX_NP=${MAX_NP}"
  echo "NP_CAND=${NP_CAND}"
  echo "NP_LIST=${NP_LIST}"
  echo "SLURM_JOB_ID=${SLURM_JOB_ID:-}"
  echo "SLURM_NTASKS=${SLURM_NTASKS:-}"
  echo "SLURM_NNODES=${SLURM_NNODES:-}"
  echo "SLURM_CPUS_ON_NODE=${SLURM_CPUS_ON_NODE:-}"
  echo "SLURM_JOB_NODELIST=${SLURM_JOB_NODELIST:-}"
  echo "SLURM_TASKS_PER_NODE=${SLURM_TASKS_PER_NODE:-}"
} > "${provenance_file}"

# -----------------------
# Header
# -----------------------
{
  echo "============================================"
  echo "MPI Game of Life Benchmark Suite"
  echo "============================================"
  echo "run_id=${run_id}"
  echo "platform=${platform}"
  echo "date_is=$(now_iso8601)"
  echo "mode=${BENCH_MODE}"
  echo "grid=${GRID_X}x${GRID_Y} steps=${STEPS} reps=${REPS}"
  echo "launcher=${LAUNCHER}"
  echo "BIND_FLAGS=${BIND_FLAGS}"
  echo "NP_LIST=${NP_LIST}"
  echo "============================================"
  echo
} >> "${bench_file}"

# -----------------------
# Helpers
# -----------------------
run_serial() {
  echo "=== SERIAL BASELINE ===" | tee -a "${bench_file}"
  for i in $(seq 1 "${REPS}"); do
    echo "-- run ${i}/${REPS} --" | tee -a "${bench_file}"
    "${SERIAL_EXE}" "${GRID_X}" "${GRID_Y}" "${STEPS}" "${PRINT_EVERY}" 2>&1 | tee -a "${bench_file}"
    echo | tee -a "${bench_file}"
  done
}

run_mpi_case() {
  local label="$1"
  local exe="$2"
  local np="$3"

  echo "=== MPI ${label} np=${np} ===" | tee -a "${bench_file}"
  for i in $(seq 1 "${REPS}"); do
    echo "-- run ${i}/${REPS} --" | tee -a "${bench_file}"
    launcher_cmd "${np}" "${exe}" "${GRID_X}" "${GRID_Y}" "${STEPS}" "${PRINT_EVERY}" 2>&1 | tee -a "${bench_file}"
    echo | tee -a "${bench_file}"
  done
}

run_compute_microbench() {
  local micro_dir="${run_dir}/tmp/compute"
  local raw_file="${micro_dir}/computation_results.txt"

  {
    echo "=========================================="
    echo "Computation microbenchmark"
    echo "=========================================="
  } > "${compute_file}"

  mkdir -p "${micro_dir}"
  rm -f "${raw_file}"
  ( cd "${micro_dir}" && "${COMP_EXE}" >/dev/null 2>&1 ) || true

  if [[ -f "${raw_file}" ]]; then
    cat "${raw_file}" >> "${compute_file}"
  else
    echo "WARNING: computation_results.txt not produced" >> "${compute_file}"
  fi
}

run_latency_microbench() {
  local micro_dir="${run_dir}/tmp/latency"
  local raw_file="${micro_dir}/latency_results.txt"

  {
    echo "=========================================="
    echo "MPI Latency microbenchmark (np=2)"
    echo "=========================================="
  } > "${latency_file}"

  if (( MAX_NP < 2 )); then
    echo "WARNING: latency microbenchmark skipped (MAX_NP=${MAX_NP}; requires >=2)" >> "${latency_file}"
    return
  fi

  mkdir -p "${micro_dir}"
  rm -f "${raw_file}"
  ( cd "${micro_dir}" && launcher_cmd 2 "${LAT_EXE}" >/dev/null 2>&1 ) || true

  if [[ -f "${raw_file}" ]]; then
    cat "${raw_file}" >> "${latency_file}"
  else
    echo "WARNING: latency_results.txt not produced" >> "${latency_file}"
  fi
}

# -----------------------
# Run suite
# -----------------------
if [[ "${BENCH_MODE}" == "full" || "${BENCH_MODE}" == "microbench" || "${BENCH_MODE}" == "latency" ]]; then
  if [[ "${USE_SRUN:-0}" == "1" ]]; then
    command -v srun >/dev/null 2>&1 || { echo "[bench] error: srun not found" >&2; exit 3; }
  else
    command -v "${MPIRUN_BIN}" >/dev/null 2>&1 || { echo "[bench] error: mpirun not found" >&2; exit 3; }
  fi
fi

if [[ "${BENCH_MODE}" == "full" ]]; then
  run_serial

  impl_labels=("ROW" "COLUMN" "MPI_BLOCK" "MPI_2D")
  impl_bins=("${ROW_EXE}" "${COL_EXE}" "${BLOCK_EXE}" "${MPI2D_EXE}")

  for np in ${NP_LIST}; do
    for k in "${!impl_labels[@]}"; do
      run_mpi_case "${impl_labels[$k]}" "${impl_bins[$k]}" "${np}"
    done
  done

  run_compute_microbench
  run_latency_microbench
elif [[ "${BENCH_MODE}" == "microbench" ]]; then
  run_compute_microbench
  run_latency_microbench
else
  run_latency_microbench
fi

echo "[bench] done"
echo "[bench] artifacts:"
find "${run_dir}" -maxdepth 2 -type f -print | sort
