# Benchmark Evidence: Job 7614

## Summary

Historical 2-node benchmark testing ROW and COLUMN decomposition strategies.

**Key Results (32 ranks):**
- **Column decomposition: 27.3x speedup** (8.654s → 0.317s)
- **Row decomposition: 16.9x speedup** (8.809s → 0.521s)

## Configuration

| Parameter | Value |
|-----------|-------|
| Job ID | 7614 |
| Date | 2026-02-09 |
| Nodes | 2 |
| Node List | node-[13-14] |
| Tasks | 32 |
| Grid | 2048x2048 |
| Steps | 300 |
| Trials | 3 |
| NP Sweep | 1, 2, 4, 8, 16, 32 |
| Launcher | mpirun --bind-to core --map-by core |

## Software

| Component | Version |
|-----------|---------|
| MPI | Open MPI 5.0.5 |
| Compiler | GNU Fortran (GCC) 13.2.0 |

## Median Results

| Impl   | np=1   | np=2   | np=4   | np=8   | np=16  | np=32  | Speedup |
|--------|--------|--------|--------|--------|--------|--------|---------|
| row    | 8.809s | 4.728s | 2.524s | 1.316s | 0.610s | 0.521s | 16.9x   |
| column | 8.654s | 4.323s | 2.359s | 1.255s | 0.630s | 0.317s | 27.3x   |

Medians calculated from `bench.txt` using `TOTAL_TIME_SEC` values (3 trials per configuration).
Speedup is computed as median(np=1) / median(np=32).

## Speedup Analysis

- **Column outperforms Row** due to better cache locality in Fortran's column-major storage
- Row decomposition suffers from strided memory access patterns
- Both implementations show good scaling up to 16 ranks, with diminishing returns at 32

## Note

This run tested only ROW and COLUMN decomposition. Later runs (job8847, job8961) added
`mpi_block` and `mpi_2d` implementations which achieve better scaling:
- **mpi_2d: 34.85x speedup** (see job8961)

## Files

| File | Description |
|------|-------------|
| `provenance.txt` | Environment snapshot and SLURM allocation |
| `bench.txt` | Full benchmark output (timing, correctness) |
| `compute.txt` | Computation microbenchmark |
| `latency.txt` | MPI latency microbenchmark |
| `slurm.out` | SLURM job output |

## Reproduction

```bash
cd MPI_game_of_life
make clean && make all
sbatch scripts/slurm/bench_2n32.slurm
```
