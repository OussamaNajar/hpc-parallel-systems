# MPI Parallelization of Conway’s Game of Life

This project explores MPI-based parallel implementations of Conway’s Game of Life as a
controlled experiment in **domain decomposition, communication patterns, and scalability**
on distributed-memory systems.

The objective is not the cellular automaton itself, but understanding how **algorithmic
structure, communication overhead, and synchronization costs** interact as parallelism
increases.

---

## Motivation

Grid-based simulations appear throughout scientific computing, physics, biology, and
large-scale numerical PDE solvers. While update rules may be simple, scalability is often
limited by **communication and data movement**, not computation.

Conway’s Game of Life provides a minimal, deterministic setting to:
- Compare alternative MPI domain decompositions
- Isolate communication costs from computation
- Study strong-scaling behavior under increasing process counts

---

## Problem Overview

The simulation evolves a 2D grid of binary cells, where each cell updates based on its
local neighborhood. In a parallel setting, the global grid is decomposed across MPI
processes.

At each timestep, boundary (halo) data must be exchanged between neighboring ranks,
introducing communication dependencies that directly affect scalability.

Key questions explored:
- How does decomposition choice affect communication volume?
- When does communication dominate computation?
- Which strategies scale more favorably with MPI rank count?

---

## Implementations

Multiple implementations are provided to isolate performance tradeoffs.

### Serial Baseline
A single-process reference implementation used to:
- Validate correctness
- Establish baseline performance
- Provide a comparison point for parallel speedup

### MPI Row-wise Decomposition
The global grid is partitioned into contiguous row blocks. Each rank exchanges halo rows
with its immediate neighbors at every timestep.

Characteristics:
- Simple communication topology
- Favorable cache locality
- Lower communication volume per rank

### MPI Column-wise Decomposition
The grid is partitioned into contiguous column blocks. Each rank exchanges halo columns
with neighbors.

This strategy introduces different memory-access and communication patterns, enabling
direct comparison with row-wise decomposition.

### Large-Scale Variants
Additional implementations (`mpi_mega`, `mpi_tera`) stress communication and synchronization
behavior at larger problem sizes and higher process counts.

---

## Performance Instrumentation

Supporting tools are included to analyze performance characteristics:

- **Latency measurement**: isolates MPI communication costs
- **Computation timing**: separates compute time from communication overhead
- **Scaling experiments**: evaluates behavior as MPI rank count increases

Experiments were executed on a SLURM-managed cluster using varying process counts.

Observed trends:
- Communication overhead dominates at higher parallelism
- Decomposition strategy significantly impacts scalability
- Row-wise decomposition generally exhibits better cache locality and scaling behavior

---

## Project Structure

```text
am250_game_of_life/
├── src/        # Serial and MPI implementations
├── scripts/    # Makefile and SLURM batch script
├── bin/        # Compiled executables (ignored by git)
└── README.md
