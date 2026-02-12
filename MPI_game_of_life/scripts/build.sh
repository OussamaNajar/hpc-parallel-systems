#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

need() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "[build] error: '$c' not found in PATH." >&2
    echo "[build] hint: on Hummingbird run:" >&2
    echo "        module purge && module load ohpc gnu13/13.2.0 openmpi5/5.0.5" >&2
    exit 2
  fi
}

need make
need gfortran
need mpif90

mkdir -p bin

echo "[build] using Makefile"
make clean
make -j all
echo "[build] complete"
