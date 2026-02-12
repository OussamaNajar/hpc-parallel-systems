# Reproduction Guide

This guide explains how to reproduce the benchmark results in this repository.

## Prerequisites

Before running any benchmarks, always perform a clean build:

```bash
cd MPI_game_of_life
make clean
make all
```

This ensures all binaries are compiled with consistent flags and avoids stale object files.

## Quick Start

```bash
cd MPI_game_of_life
make clean
make all
sbatch scripts/slurm/bench_2n32.slurm
```

## Reproducing Results on Cluster

Hummingbird does not have a compatible `srun --mpi=` plugin. All MPI benchmarks use:

```bash
mpirun --bind-to core --map-by core -np <np> ./bin/<exe>
```

Ensure reproducibility by checking that `provenance.txt` contains a real `git_commit`.

## Build

The `Makefile` is located at `MPI_game_of_life/Makefile`:

```bash
cd MPI_game_of_life
make clean    # Remove old binaries and object files
make all      # Compile all implementations
```

Always run `make clean` before `make all` when switching branches or after pulling updates.

## SLURM Scripts

Located in `scripts/slurm/`:

| Script | Description |
|--------|-------------|
| `bench.slurm` | Basic benchmark |
| `bench_2n16.slurm` | 2-node, 16 ranks |
| `bench_2n32.slurm` | 2-node, 32 ranks (headline results) |
| `sanity_1n8.slurm` | Quick sanity check |
| `latency_1node.slurm` | MPI latency test (1 node) |
| `latency_2node.slurm` | MPI latency test (2 nodes) |

Submit examples:

```bash
cd MPI_game_of_life
sbatch scripts/slurm/bench_2n16.slurm
sbatch scripts/slurm/bench_2n32.slurm
```

## Local Run

For local testing without SLURM:

```bash
cd MPI_game_of_life
make clean && make all
bash tests/smoke.sh           # Validate correctness
bash scripts/bench.sh         # Run benchmarks locally
```

## Output Location

Each run writes to:

```
experiments/{platform}/{YYYY-MM-DD}_{tag}/
```

Expected files:

| File | Purpose |
|------|---------|
| `provenance.txt` | Environment snapshot |
| `stdout.txt` | Full output log |
| `results/bench.txt` | Timing data |
| `results/latency.txt` | MPI latency measurements |
| `results/compute.txt` | Computation microbenchmark |

## Validation Checklist

1. `ALIVE_FINAL: 5` appears for all implementations (correctness check)
2. `provenance.txt` captures compiler/MPI versions and launcher metadata
3. `results/bench.txt` contains raw per-trial timings (3 trials per configuration)
4. `results/latency.txt` and `results/compute.txt` are present
5. `MPI Ranks: <np>` matches the requested rank count (not always 1)

## Notes

- The canonical benchmark script is `scripts/bench.sh`
- Curated results are stored in `results/hummingbird/`
- Invalid historical runs are archived in `results/hummingbird/_invalid_srun/`
