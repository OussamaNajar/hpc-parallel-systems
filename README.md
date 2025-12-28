# HPC Parallel Systems

A small portfolio of high-performance computing projects focused on MPI-based parallelism,
communication patterns, and performance analysis.

## Projects

### MPI Game of Life (Fortran + MPI)
Parallel implementations of Conway’s Game of Life to study distributed-memory scaling:

- Serial baseline for correctness and reference timing
- MPI row/column domain decomposition with halo exchange
- Large-scale variants (`mpi_mega` / `mpi_tera`) to stress communication and scaling limits
- Microbenchmarks for latency and computation time separation
- SLURM batch runner for cluster execution

**Code:** `am250_game_of_life/`  
**Build:** `cd am250_game_of_life && make -f scripts/Makefile all`  
**Run:** `cd am250_game_of_life && mpirun -np 4 ./bin/row`

## Running on an HPC Cluster (SLURM)

This project includes a SLURM batch script for execution on distributed-memory clusters.

Example usage:

```bash
cd am250_game_of_life
make -f scripts/Makefile all
sbatch scripts/SLURM.sh
