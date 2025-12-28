# HPC Parallel Systems

A small portfolio of high-performance computing projects focused on MPI-based parallelism,
communication patterns, and performance analysis.

## Projects

### MPI Game of Life (Fortran + MPI)
Parallel implementations of Conway’s Game of Life to study distributed-memory scaling:

- Serial baseline for correctness and reference timing
- MPI row/column domain decomposition with halo exchange
- Large-scale variants (`mega` / `tera`) to stress communication and scaling limits
- Microbenchmarks for latency and computation time separation
- SLURM batch runner for cluster execution

**Code:** `am250_game_of_life/`  
**Build:** `make -f am250_game_of_life/scripts/Makefile all`  
**Run (example):** `mpirun -np 4 ./am250_game_of_life/bin/row`
