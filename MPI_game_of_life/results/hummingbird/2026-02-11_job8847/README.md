# Benchmark Evidence: Job 8847

## Summary

1-node strong-scaling benchmark across 4 MPI decomposition strategies plus serial baseline.

**Headline Result:** 2D Cartesian achieves **18.7x speedup vs serial** on 16 MPI ranks / 1 node, reducing runtime from 12.12 s to 0.649 s.

---

## Methodology

### Speedup Definitions

Two speedup metrics are reported to provide full transparency:

- **Speedup vs Serial** = `median(serial, np=1) / median(impl, np=N)` — standard HPC convention. This answers: "how much faster is the parallel version compared to the best single-core option (no MPI overhead)?"
- **Scaling (impl np=1)** = `median(impl, np=1) / median(impl, np=N)` — measures parallel scaling efficiency within each implementation's own MPI codepath. This answers: "given this implementation at 1 rank, how much faster is it at N ranks?"

Both are valid metrics. "Speedup vs Serial" is the standard reported in HPC papers and on the resume. "Scaling (impl np=1)" isolates the parallel efficiency from single-rank MPI overhead.

### Why np=1 ≠ Serial

The serial program has no `MPI_Init`, no halo exchange buffers, no communicator setup. MPI implementations at np=1 still execute the full MPI code path (initialization, decomposition logic, halo bookkeeping, buffer allocation) even though no inter-rank communication occurs. On this hardware, the overhead is small for 2D/Block/Column (within ~2%), but Row np=1 is 12.5% slower than serial.

### Statistical Method

All times are **medians of 3 trials**. Correctness verified: ALIVE_FINAL = 5 and CHECKSUM_FINAL = 386001545 for all runs.

---

## Configuration

| Parameter | Value                        |
|-----------|------------------------------|
| Job ID    | 8847                         |
| Date      | 2026-02-11                   |
| Nodes     | 1                            |
| Node List | node-12                      |
| CPUs/Node | 16                           |
| Tasks     | 16                           |
| Grid      | 2048 x 2048                  |
| Steps     | 300                          |
| Trials    | 3                            |
| NP Sweep  | 1, 2, 4, 8, 16              |
| Launcher  | mpirun                       |
| Binding   | No explicit bind flags recorded in provenance |

## Software

| Component | Version                  |
|-----------|--------------------------|
| MPI       | Open MPI 5.0.5           |
| Compiler  | GNU Fortran (GCC) 13.2.0 |

---

## Results

Serial baseline: **12.121 s** (median of 3 trials: 12.102, 12.121, 12.243)

| Impl      | np=1     | np=2    | np=4    | np=8    | np=16   | Speedup vs Serial | Scaling (impl np=1) |
|-----------|----------|---------|---------|---------|---------|-------------------|----------------------|
| mpi_2d    | 11.912s  | 6.407s  | 2.600s  | 1.375s  | 0.649s  | 18.7x             | 18.4x                |
| mpi_block | 12.039s  | 6.448s  | 2.623s  | 1.400s  | 0.670s  | 18.1x             | 18.0x                |
| column    | 11.956s  | 4.625s  | 2.493s  | 1.370s  | 0.687s  | 17.7x             | 17.4x                |
| row       | 13.637s  | 6.973s  | 3.849s  | 2.021s  | 1.369s  | 8.9x              | 10.0x                |

**Note:** Row's "Scaling" (10.0x) exceeds its "Speedup vs Serial" (8.9x) because Row np=1 is 12.5% slower than serial due to MPI initialization and decomposition/halo bookkeeping overhead at single rank.

---

## MPI Overhead at np=1

| Implementation | np=1 Time | Overhead vs Serial |
|----------------|-----------|---------------------|
| Serial         | 12.121s   | (baseline)          |
| mpi_2d         | 11.912s   | -1.7%               |
| mpi_block      | 12.039s   | -0.7%               |
| column         | 11.956s   | -1.4%               |
| row            | 13.637s   | +12.5%              |

For 2D, Block, and Column, np=1 is slightly faster than serial (likely due to minor differences in loop structure or compiler optimization across source files). Row np=1 is 12.5% slower, reflecting the overhead of its decomposition and strided memory access pattern in Fortran column-major layout.

---

## Performance Model Parameters

Measured on this hardware (1 node, intra-node communication):

| Parameter | Value               | Description                                                      |
|-----------|---------------------|------------------------------------------------------------------|
| t_c       | 48.72 ns/cell-update | Per-cell computation cost (from 20x20 grid microbenchmark)      |
| t_s       | 0.406 µs            | MPI startup latency (from ping-pong at smallest message size)   |
| t_w       | 0.128 ns/byte       | Per-byte transfer cost (from large-message asymptotic bandwidth) |

### Caution on t_c

The 20x20 microbenchmark grid measures t_c = 48.72 ns/cell-update, but the effective per-cell cost derived from the serial baseline is only **9.63 ns** (= 12.121 s / (300 × 2048²)). The microbenchmark is **5.1x slower** than the actual application.

This is the opposite of what simple "cache-resident = fast" reasoning predicts. The likely explanation is that the full 2048x2048 application benefits from compiler vectorization and loop optimizations that require large, regular iteration spaces to be effective. The tiny 20x20 kernel is too small for these optimizations to engage.

**Consequence:** The performance model using microbench t_c will significantly **overpredict** runtimes. See the Model vs Observed section below.

---

### Performance Model Formulas

> Halo exchanges send one value per boundary cell. Implementation uses `MPI_INTEGER` halos (assume 4 bytes/cell for these runs). Formulas use 4 bytes/cell.

**For 1D decomposition (Row or Column, p ranks, N×N grid, S steps):**

```
T_comp = S × (N² / p) × t_c
T_comm = S × 2 × (t_s + N × 4 × t_w)        # 2 neighbors, each exchanges N cells × 4 bytes (MPI_INTEGER)
T_total = T_comp + T_comm
```

**For 2D Cartesian decomposition (p ranks as √p × √p, N×N grid, S steps):**

```
T_comp = S × (N² / p) × t_c
T_comm = S × 4 × (t_s + (N / √p) × 4 × t_w) # 4 neighbors, each exchanges N/√p cells × 4 bytes (MPI_INTEGER)
T_total = T_comp + T_comm
```

---

### Model vs Observed

Using this job's microbenchmark parameters over 300 timesteps:

**2D Cartesian at np=16, N=2048:**

```
T_comp = 300 × (2048² / 16) × 48.72 ns = 3.831 s
T_comm = 300 × 4 × (0.406 µs + (2048/4) × 4 × 0.128 ns) = 0.0008 s
T_predicted = 3.832 s
T_observed  = 0.649 s  →  model overpredicts by ~5.9x
```

**Column at np=16, N=2048:**

```
T_comp = 300 × (2048² / 16) × 48.72 ns = 3.831 s
T_comm = 300 × 2 × (0.406 µs + 2048 × 4 × 0.128 ns) = 0.0009 s
T_predicted = 3.832 s
T_observed  = 0.687 s  →  model overpredicts by ~5.6x
```

**Why the model is ~5-6x off:** The microbenchmark t_c (48.72 ns) is 5.1x larger than the effective per-cell cost in the actual application (9.63 ns). The 20x20 microbenchmark grid is too small for compiler vectorization and loop optimizations to engage. Using the serial-derived t_c (9.63 ns) instead would predict 0.760 s for 2D @16, which is much closer to the observed 0.649 s (17% over — reasonable given unmodeled optimizations like communication/computation overlap).

**Takeaway:** The microbenchmark t_c is a poor predictor of absolute runtime on this hardware. The model's primary value is in **relative comparisons** (e.g., 2D vs Row) and in identifying which regime (compute-dominated vs communication-dominated) the workload is in. The communication cost (~0.001 s) is negligible at this scale — all decompositions are firmly compute-dominated on 1 node.

---

## Speedup Analysis

- All four implementations are limited to 16 ranks (single node, 16 cores).
- **2D Cartesian** leads at 18.7x, followed closely by **Block** (18.1x) and **Column** (17.7x).
- **Row** (8.9x) shows the impact of strided memory access in Fortran column-major layout, even without inter-node communication overhead.
- The 2-node results (job 8961) show all implementations scale further to 32 ranks.

---

## Comparison with Other Runs

| Metric                 | Job 8847 (this run)            | Job 8961                                         | Job 7614                                         |
|------------------------|--------------------------------|--------------------------------------------------|--------------------------------------------------|
| Nodes                  | 1                              | 2                                                | 2 (Broadwell, historical)                        |
| Max ranks              | 16                             | 32                                               | 32                                               |
| Serial baseline        | 12.121 s                       | 12.180 s                                         | 19.553 s                                         |
| Best speedup vs serial | 18.7x (2D @16)                | 34.9x (2D @32)                                   | 61.7x (Column @32, inflated — see job 7614 README) |
| Implementations        | All 4                          | All 4                                            | Row, Column only                                 |

---

## Files

| File              | Description                                                                      |
|-------------------|----------------------------------------------------------------------------------|
| `provenance.txt`  | Environment snapshot (hostname, compiler, MPI, SLURM allocation)                |
| `bench.txt`       | Full benchmark output (all trials, timing breakdown, correctness)               |
| `compute.txt`     | Computation microbenchmark (t_c estimation from 20x20 grid, 10000 iterations)   |
| `latency.txt`     | MPI latency/bandwidth microbenchmark (t_s, t_w estimation from ping-pong sweep) |

---

## Reproduction

```bash
cd MPI_game_of_life
make clean && make all
sbatch scripts/slurm/bench.slurm
```