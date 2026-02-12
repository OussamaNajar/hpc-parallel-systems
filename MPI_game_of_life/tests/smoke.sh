#!/usr/bin/env bash
# Smoke test: verify all implementations produce matching checksums
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

# Test parameters (small grid for fast testing)
N=64
STEPS=100
NP=4

echo "=== MPI Game of Life Smoke Test ==="
echo "Grid: ${N}x${N}, Steps: ${STEPS}, NP: ${NP}"
echo ""

# Check binaries exist
for bin in serial row column mpi_block mpi_2d; do
    if [[ ! -x "bin/${bin}" ]]; then
        echo "ERROR: bin/${bin} not found. Run 'make all' first."
        exit 1
    fi
done

# Detect mpirun oversubscribe support
OVERSUBSCRIBE=""
if mpirun --help 2>&1 | grep -q "oversubscribe"; then
    OVERSUBSCRIBE="--oversubscribe"
fi

# Get serial reference checksum
echo "Running serial baseline..."
SERIAL_OUTPUT=$(./bin/serial ${N} ${N} ${STEPS} 0)
SERIAL_CHECKSUM=$(echo "${SERIAL_OUTPUT}" | grep "CHECKSUM_FINAL:" | awk '{print $2}')
SERIAL_ALIVE=$(echo "${SERIAL_OUTPUT}" | grep "ALIVE_FINAL:" | awk '{print $2}')

if [[ -z "${SERIAL_CHECKSUM}" ]]; then
    echo "ERROR: Could not extract serial checksum"
    exit 1
fi

echo "  ALIVE_FINAL: ${SERIAL_ALIVE}"
echo "  CHECKSUM_FINAL: ${SERIAL_CHECKSUM} (reference)"
echo ""

# Test each MPI implementation
FAILED=0
for impl in row column mpi_block mpi_2d; do
    echo "Testing ${impl} (np=${NP})..."
    
    OUTPUT=$(mpirun ${OVERSUBSCRIBE} -np ${NP} ./bin/${impl} ${N} ${N} ${STEPS} 0 2>&1)
    CHECKSUM=$(echo "${OUTPUT}" | grep "CHECKSUM_FINAL:" | awk '{print $2}')
    ALIVE=$(echo "${OUTPUT}" | grep "ALIVE_FINAL:" | awk '{print $2}')
    
    if [[ -z "${CHECKSUM}" ]]; then
        echo "  ERROR: Could not extract checksum"
        FAILED=1
        continue
    fi
    
    if [[ "${CHECKSUM}" == "${SERIAL_CHECKSUM}" ]]; then
        echo "  ALIVE_FINAL: ${ALIVE}"
        echo "  CHECKSUM_FINAL: ${CHECKSUM} MATCH"
    else
        echo "  ALIVE_FINAL: ${ALIVE}"
        echo "  CHECKSUM_FINAL: ${CHECKSUM} MISMATCH (expected ${SERIAL_CHECKSUM})"
        FAILED=1
    fi
    echo ""
done

# Summary
if [[ ${FAILED} -eq 0 ]]; then
    echo "=== ALL TESTS PASSED ==="
    exit 0
else
    echo "=== SOME TESTS FAILED ==="
    exit 1
fi
