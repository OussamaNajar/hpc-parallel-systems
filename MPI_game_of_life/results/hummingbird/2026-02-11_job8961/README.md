# Benchmark Evidence: Job 8961

## Config
- Nodes: 2
- Tasks: 32
- Grid: 2048x2048
- Steps: 300
- Launcher: `mpirun --bind-to core --map-by core`
- MPI: Open MPI 5.0.5
- Commit (from `provenance.txt`): `unavailable`

## Median Results

Serial baseline: **12.180 s** (median of 3 trials: 11.997, 12.180, 12.273)

| Impl      | np=1    | np=2   | np=4   | np=8   | np=16  | np=32  | Speedup vs Serial | Scaling (impl np=1) |
|-----------|---------|--------|--------|--------|--------|--------|-------------------|---------------------|
| mpi_2d    | 12.148s | 6.551s | 2.597s | 1.383s | 0.656s | 0.349s | 34.9x             | 34.9x               |
| mpi_block | 12.122s | 6.548s | 2.624s | 1.396s | 0.664s | 0.350s | 34.8x             | 34.6x               |
| column    | 12.074s | 4.713s | 2.520s | 1.351s | 0.667s | 0.360s | 33.8x             | 33.5x               |
| row       | 13.732s | 7.053s | 3.911s | 2.030s | 1.147s | 0.593s | 20.5x             | 23.2x               |

> Speedup vs Serial = serial_median / impl_median(np=32). Scaling (impl np=1) = impl_median(np=1) / impl_median(np=32). Speedups computed from exact median times (unrounded) and rounded to 1 decimal. Row Scaling (23.2x) > Speedup vs Serial (20.5x) because Row np=1 is 13% slower than serial due to MPI overhead.

Medians are calculated from `bench.txt` using `TOTAL_TIME_SEC` values (3 trials per configuration).
