# MPI Parallelization of Conway's Game of Life

This project explores MPI-based parallel implementations of Conway's Game of Life as a
controlled experiment in **domain decomposition, communication patterns, and scalability**
on distributed-memory systems.

**The objective is not the cellular automaton itself**, but understanding how algorithmic
structure, communication overhead, and synchronization costs interact as parallelism
increases.

This project emphasizes correctness, reproducibility, and performance analysis over raw
speed, mirroring real HPC development workflows.

---

## Motivation

Grid-based simulations appear throughout scientific computing, physics, biology, and
large-scale numerical PDE solvers. While update rules may be simple, scalability is often
limited by **communication and data movement**, not computation.

Conway's Game of Life provides a minimal, deterministic setting to:
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

**Key questions explored:**
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

**Characteristics:**
- Simple communication topology
- Favorable cache locality (row-major Fortran arrays)
- Lower communication volume per rank

### MPI Column-wise Decomposition
The grid is partitioned into contiguous column blocks. Each rank exchanges halo columns
with neighbors.

This strategy introduces different memory-access and communication patterns, enabling
direct comparison with row-wise decomposition.

### 2D Block Decomposition
Additional implementations (`mpi_block`, `mpi_2d`) use coarse-grained 2D domain decomposition
to stress communication volume and synchronization behavior at larger grid sizes and higher
process counts.

---

## Benchmark Mode

All implementations support a benchmark mode via command-line arguments:

```bash
./program NX NY STEPS PRINT_EVERY
```

**Parameters:**
- `NX`, `NY`: grid dimensions
- `STEPS`: number of simulation steps
- `PRINT_EVERY = 0`: disables grid output (benchmark mode)

**Example runs:**
```bash
./bin/serial 2048 2048 300 0
mpirun -np 4 ./bin/row 2048 2048 300 0
```

**Output metrics (benchmark mode):**
- `TOTAL_TIME_SEC`: End-to-end wall time
- `COMM_TIME_SEC`: Time spent in MPI communication (MPI versions)
- `COMP_TIME_SEC`: Computation time
- `COMM_FRACTION`: Communication as percentage of total time
- `ALIVE_FINAL`: Final alive cell count (correctness check)

This allows reproducible strong-scaling and communication analysis without I/O overhead.

---

## Performance Instrumentation

Supporting tools are included to analyze performance characteristics:

- **Latency measurement** (`latency.f90`): Isolates MPI communication costs
- **Computation timing** (`computation_time.f90`): Separates compute time from communication overhead
- **Strong-scaling experiments**: Evaluates behavior as MPI rank count increases

Experiments were executed on a SLURM-managed HPC cluster using varying process counts.

---

## Strong Scaling Results

**Benchmark configuration:**
- Grid size: 2048 × 2048
- Timesteps: 300
- Output disabled (PRINT_EVERY=0)
- 3 runs per configuration; values reported as mean

**Serial baseline (mean of 3 runs):**
- `TOTAL_TIME_SEC = 9.173 s` (`ALIVE_FINAL = 5`)

### Row-wise Decomposition (mean of 3 runs)

| MPI Ranks | Mean Time (s) | Speedup | Parallel Efficiency | Comm. Fraction |
|-----------|---------------|---------|---------------------|----------------|
| 2         | 3.873         | 2.37×   | 118%                | ~1–2%          |
| 4         | 2.432         | 3.77×   | 94%                 | ~6–9%          |
| 8         | 2.481         | 3.70×   | 46%                 | ~41–44%        |

### Column-wise Decomposition (mean of 3 runs)

| MPI Ranks | Mean Time (s) | Speedup | Parallel Efficiency | Comm. Fraction |
|-----------|---------------|---------|---------------------|----------------|
| 2         | 3.369         | 2.72×   | 136%                | ~0.6–1.0%      |
| 4         | 2.379         | 3.86×   | 97%                 | ~6–9%          |
| 8         | 2.165         | 4.24×   | 53%                 | ~40–42%        |

---

## Performance Analysis

### Strong-Scaling Behavior

Strong-scaling efficiency remains above 94% through 4 MPI ranks for both decomposition 
strategies, after which communication overhead becomes the dominant cost. At 8 ranks, 
halo exchanges account for approximately 40–44% of total runtime, limiting further 
scalability.

Column-wise decomposition achieves better overall speedup at 8 ranks (4.24× vs 3.70×), 
while row-wise decomposition shows performance degradation from 4 to 8 ranks. This suggests 
that at higher concurrency, column-wise benefits from better load balance or reduced 
synchronization costs despite slightly higher communication fraction.

### Superlinear Speedup at Low Rank Count

The observed superlinear speedup at 2 ranks (2.37× row, 2.72× column) is consistent with 
cache effects: per-rank working sets (1024×2048 or 2048×1024) fit better in cache hierarchy 
than the full 2048×2048 serial grid, reducing memory access latency and improving 
computational throughput. Column-wise decomposition shows stronger superlinear behavior, 
likely due to more favorable cache line alignment.

### Communication Scaling

Communication overhead scales non-linearly with rank count:
- **2 ranks:** ~1% (negligible)
- **4 ranks:** ~6–9% (moderate)
- **8 ranks:** ~40–44% (dominant)

This progression illustrates classical strong-scaling saturation, where reduced per-rank 
computation is offset by increasing communication and synchronization costs.

### Decomposition Strategy Comparison

At low rank counts (2–4), both strategies perform similarly with slight advantage to 
column-wise. At 8 ranks, column-wise decomposition significantly outperforms row-wise 
(4.24× vs 3.70× speedup), despite similar communication fractions.

Row-wise decomposition shows unexpected performance plateau/degradation from 4 to 8 ranks 
(3.77× → 3.70×), while column-wise continues to improve (3.86× → 4.24×). This may indicate 
load imbalance, synchronization bottlenecks, or NUMA effects in the row-wise implementation 
at higher concurrency.

The analysis confirms that for grid-based simulations at moderate parallelism, decomposition 
strategy critically impacts performance, with column-wise demonstrating better scaling 
characteristics at higher rank counts for this problem size and system configuration.

---

## Project Structure

```text
MPI_game_of_life/
├── src/                    # Serial and MPI implementations
│   ├── serial.f90         # Serial baseline
│   ├── row.f90            # Row-wise MPI decomposition
│   ├── column.f90         # Column-wise MPI decomposition
│   ├── mpi_block.f90      # 2D block decomposition
│   ├── mpi_2d.f90         # Alternative 2D decomposition
│   ├── latency.f90        # MPI latency measurement
│   └── computation_time.f90  # Computation timing tool
├── scripts/               # Build and execution scripts
│   ├── Makefile          # Build configuration
│   └── SLURM.sh         # SLURM batch script
├── bin/                  # Compiled executables (gitignored)
├── benchmark_results.txt # Reproducible benchmark output
└── README.md
```

---

## Building and Running

**Compile all implementations:**
```bash
cd MPI_game_of_life
make -f scripts/Makefile all
```

**Run row-wise decomposition with 4 processes:**
```bash
mpirun -np 4 ./bin/row 2048 2048 300 0
```

**Run full benchmark suite:**
```bash
./run_benchmarks.sh
```

**Submit to SLURM cluster:**
```bash
sbatch scripts/SLURM.sh
```

---

## Technical Notes

- **Language:** Fortran 90
- **MPI operations:** Point-to-point (Send/Recv), Collective (Gatherv)
- **Memory layout:** Row-major (Fortran default)
- **Boundary conditions:** Periodic
- **Performance measurement:** MPI_Wtime for timing, manual instrumentation for communication overhead
- **Reproducibility:** All results based on mean of 3 runs with identical parameters
