# MPI Game of Life

This project contains serial and MPI implementations of Conway's Game of Life, plus scripts for reproducible benchmarking.

## Benchmark Results (Median Runtime)

Workload for all tables:
- Grid: 2048x2048
- Steps: 300
- Trials per point: 3
- Metric: median `TOTAL_TIME_SEC`

### 1 Node (job 8847)

Serial baseline: **12.121 s** (median of 3 trials, job 8847)

| Impl      | np=1    | np=2   | np=4   | np=8   | np=16  | Speedup vs Serial | Scaling (impl np=1) |
|-----------|---------|--------|--------|--------|--------|-------------------|---------------------|
| mpi_2d    | 11.912s | 6.407s | 2.600s | 1.375s | 0.649s | 18.7x             | 18.4x               |
| mpi_block | 12.039s | 6.448s | 2.623s | 1.400s | 0.670s | 18.1x             | 18.0x               |
| column    | 11.956s | 4.625s | 2.493s | 1.370s | 0.687s | 17.7x             | 17.4x               |
| row       | 13.637s | 6.973s | 3.849s | 2.021s | 1.369s | 8.9x              | 10.0x               |

> Speedup vs Serial = serial_median / impl_median(np=16). Scaling (impl np=1) = impl_median(np=1) / impl_median(np=16). Speedups computed from exact median times (unrounded) and rounded to 1 decimal. Row Scaling (10.0x) > Speedup vs Serial (8.9x) because Row np=1 carries 12.5% MPI overhead vs serial.

### 2 Nodes (job 8961)

Serial baseline: **12.180 s** (median of 3 trials, job 8961)

| Impl      | np=1    | np=2   | np=4   | np=8   | np=16  | np=32  | Speedup vs Serial | Scaling (impl np=1) |
|-----------|---------|--------|--------|--------|--------|--------|-------------------|---------------------|
| mpi_2d    | 12.148s | 6.551s | 2.597s | 1.383s | 0.656s | 0.349s | 34.9x             | 34.9x               |
| mpi_block | 12.122s | 6.548s | 2.624s | 1.396s | 0.664s | 0.350s | 34.8x             | 34.6x               |
| column    | 12.074s | 4.713s | 2.520s | 1.351s | 0.667s | 0.360s | 33.8x             | 33.5x               |
| row       | 13.732s | 7.053s | 3.911s | 2.030s | 1.147s | 0.593s | 20.5x             | 23.2x               |

> Speedup vs Serial = serial_median / impl_median(np=32). Scaling (impl np=1) = impl_median(np=1) / impl_median(np=32). Speedups computed from exact median times (unrounded) and rounded to 1 decimal. Row Scaling (23.2x) > Speedup vs Serial (20.5x) because Row np=1 is 13% slower than serial due to MPI overhead.

Raw evidence is under `results/hummingbird/` and summarized in `docs/results.md`.

## Dependencies

### Ubuntu or Debian

```bash
sudo apt-get update
sudo apt-get install -y make gfortran openmpi-bin libopenmpi-dev
```

### macOS (Homebrew)

```bash
brew install gcc open-mpi
```

### RHEL or CentOS (module environment)

```bash
module load gnu openmpi
```

## Build

```bash
cd MPI_game_of_life
make clean
make all
```

## Run Locally

Single run:

```bash
mpirun -np 4 ./bin/mpi_2d 256 256 100 0
```

Local benchmark script:

```bash
bash scripts/bench.sh
```

## Cluster Run (SLURM)

```bash
sbatch scripts/slurm/bench_2n32.slurm
```

Use `mpirun` with core binding for benchmark runs:

```bash
mpirun --bind-to core --map-by core -np <np> ./bin/<exe>
```

## Smoke Test

```bash
bash tests/smoke.sh
```

## Implementations

| File | Strategy |
|------|----------|
| `src/serial.f90` | Serial baseline |
| `src/row.f90` | 1D row decomposition |
| `src/column.f90` | 1D column decomposition |
| `src/mpi_block.f90` | Manual 2D block decomposition |
| `src/mpi_2d.f90` | 2D Cartesian communicator |

## Project Layout

```text
MPI_game_of_life/
  src/                 Fortran source files
  bin/                 Compiled binaries
  scripts/             Build, benchmark, and SLURM scripts
  tests/               Smoke tests
  docs/                Methodology and performance notes
  results/hummingbird/ Curated benchmark evidence
```

## NOTE

The `_invalid_srun/` folder is intentionally preserved as a historical record of an earlier `srun` launch issue. It is not used for current benchmark claims or automated tests.

## License

MIT. See `../LICENSE`.
