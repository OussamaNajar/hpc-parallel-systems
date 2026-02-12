# HPC Parallel Systems

MPI parallelization project demonstrating strong scaling on distributed memory systems.

## Key Result

**34.85x speedup on 32 cores across 2 nodes** using 2D Cartesian decomposition.

See full results in [`MPI_game_of_life/results/hummingbird/2026-02-11_job8961/`](MPI_game_of_life/results/hummingbird/2026-02-11_job8961/)

## Project

### MPI Game of Life

Location: `MPI_game_of_life/`

Implements 5 parallelization strategies for Conway's Game of Life:
- Serial baseline
- Row decomposition (1D)
- Column decomposition (1D)
- Block decomposition (2D manual)
- Cartesian topology (2D with MPI_Cart)

## Dependencies

### Ubuntu / Debian

```bash
sudo apt-get update
sudo apt-get install -y make gfortran openmpi-bin libopenmpi-dev
```

### macOS (Homebrew)

```bash
brew install gcc open-mpi
```

### RHEL / CentOS (module environment)

```bash
module load gnu openmpi
```

### Verify Installation

```bash
gfortran --version
mpirun --version
```

## Quick Start

```bash
cd MPI_game_of_life
make clean && make all

# Run smoke test (validates correctness)
bash tests/smoke.sh

# Run locally with 4 ranks
mpirun -np 4 ./bin/mpi_2d 256 256 100 0
```

## Documentation

- [MPI_game_of_life/README.md](MPI_game_of_life/README.md) — Full project documentation
- [docs/results.md](MPI_game_of_life/docs/results.md) — Benchmark results summary
- [docs/methodology.md](MPI_game_of_life/docs/methodology.md) — Benchmark methodology
- [docs/reproduction.md](MPI_game_of_life/docs/reproduction.md) — Reproduction guide

## License

MIT. See [LICENSE](LICENSE).
