#!/usr/bin/env bash
set -euo pipefail

platform="${1:-${BENCH_PLATFORM:-hummingbird}}"
root="experiments/${platform}"

latest="$(ls -1dt ${root}/* 2>/dev/null | head -n 1 || true)"
if [[ -z "${latest}" ]]; then
  echo "No runs found under ${root}" >&2
  exit 1
fi

echo "Latest run: ${latest}"
echo "Files:"
find "${latest}" -maxdepth 2 -type f -print | sort

bench="${latest}/results/bench.txt"
if [[ -f "${bench}" ]]; then
  echo
  echo "=== Key lines (np + speedup markers) ==="
  grep -nE "SERIAL|np=1|np=32|COLUMN|ROW|Speedup|Avg|Mean|bind|report-bindings" "${bench}" | head -n 200 || true
fi
