# Benchmark Methodology

## Canonical Run

Job 8961 (2026-02-11): 34.9x speedup vs serial on 32 cores across 2 nodes (34.85x self-scaling).
Evidence: `results/hummingbird/2026-02-11_job8961/`.

## Workload

| Parameter | Value |
|-----------|-------|
| Grid | 2048 x 2048 |
| Timesteps | 300 |
| Trials | 3 per configuration |
| Metric | Median time |

## MPI Configuration

```bash
mpirun --bind-to core --map-by core -np $NP ./bin/mpi_2d ...
```

- `OMP_NUM_THREADS=1` for pure MPI runs
- `USE_SRUN=0` so benchmarks use `mpirun`

## Platform (Job 8961)

| Component | Value |
|-----------|-------|
| Cluster | Hummingbird (UCSC) |
| Nodes | 2 (node-06, node-18) |
| Tasks | 32 |
| MPI | Open MPI 5.0.5 |
| Compiler | GNU Fortran 13.2.0 |

## Validation

- Correctness: `CHECKSUM_FINAL: 386001545`
- Launcher: `launcher=mpirun` in provenance
- Rank count: `MPI Ranks: <np>` matches the requested `np`
