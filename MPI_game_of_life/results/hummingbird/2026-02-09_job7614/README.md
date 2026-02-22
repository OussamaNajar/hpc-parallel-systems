# Benchmark Evidence: Job 7614

## Historical Run — Different Hardware

This run executed on **Intel Xeon E5-2650 v4 (Broadwell)** nodes, which differ from the nodes used in jobs 8847/8961. Results are **not directly comparable** to those runs.

Key differences from jobs 8847/8961:

- Serial baseline ~1.6x slower (19.55 s vs 12.18 s)
- Anomalous 2.2x gap between serial and MPI np=1 (see [anomaly section](#serial-vs-mpi-np1-anomaly))
- Microbenchmark t_c 6.4x faster (7.67 ns vs ~49 ns) — 20x20 grid is cache-resident; sensitive to cache effects and hardware (see [caution](#caution-on-t_c))
- Only Row and Column tested (no mpi_2d or mpi_block)

**For primary benchmark results used in the project README and resume, see job 8847 (1-node) and job 8961 (2-node).**

---

## Summary

Historical 2-node benchmark testing Row and Column decomposition strategies.

---

## Methodology

### Speedup Definitions

Two speedup metrics are reported to provide full transparency:

- **Speedup vs Serial** = `median(serial, np=1) / median(impl, np=N)` — standard HPC convention. This answers: "how much faster is the parallel version compared to the best single-core option (no MPI overhead)?"
- **Scaling (impl np=1)** = `median(impl, np=1) / median(impl, np=N)` — measures parallel scaling efficiency within each implementation's own MPI codepath. This answers: "given this implementation at 1 rank, how much faster is it at N ranks?"

Both are valid metrics. "Speedup vs Serial" is the standard reported in HPC papers and on the resume. "Scaling (impl np=1)" isolates the parallel efficiency from single-rank MPI overhead.

### Why np=1 ≠ Serial

The serial program has no `MPI_Init`, no halo exchange buffers, no communicator setup. MPI implementations at np=1 still execute the full MPI code path (initialization, decomposition logic, halo bookkeeping, buffer allocation) even though no inter-rank communication occurs. This overhead is typically small on the jobs 8847/8961 hardware (where serial ≈ MPI np=1), but on this hardware the gap is anomalously large (see below).

### Statistical Method

All times are **medians of 3 trials**. Correctness verified: ALIVE_FINAL = 5 for all runs.

---

## Configuration

| Parameter | Value                                                                                                                        |
|-----------|------------------------------------------------------------------------------------------------------------------------------|
| Job ID    | 7614                                                                                                                         |
| Date      | 2026-02-09                                                                                                                   |
| Nodes     | 2                                                                                                                            |
| Node List | node-[13-14]                                                                                                                 |
| Tasks     | 32                                                                                                                           |
| Grid      | 2048 x 2048                                                                                                                  |
| Steps     | 300                                                                                                                          |
| Trials    | 3                                                                                                                            |
| NP Sweep  | 1, 2, 4, 8, 16, 32                                                                                                          |
| Launcher  | mpirun                                                                                                                       |
| Binding   | No explicit `--bind-to` / `--map-by` flags recorded in provenance; Open MPI printed per-rank binding messages during launch  |
| CPU       | Intel Xeon E5-2650 v4 @ 2.20GHz (Broadwell)                                                                                 |

## Software

| Component | Version                  |
|-----------|--------------------------|
| MPI       | Open MPI 5.0.5           |
| Compiler  | GNU Fortran (GCC) 13.2.0 |

---

## Results

Serial baseline: **19.553 s** (median of 3 trials: 19.545, 19.553, 19.953)

| Impl   | np=1    | np=2    | np=4    | np=8    | np=16   | np=32   | Speedup vs Serial | Scaling (impl np=1) |
|--------|---------|---------|---------|---------|---------|---------|-------------------|----------------------|
| column | 8.654s  | 4.323s  | 2.359s  | 1.255s  | 0.630s  | 0.317s  | 61.7x             | 27.3x                |
| row    | 8.809s  | 4.728s  | 2.524s  | 1.316s  | 0.610s  | 0.521s  | 37.6x             | 16.9x                |

> Speedup vs Serial = serial_median / impl_median(np=32). Scaling (impl np=1) = impl_median(np=1) / impl_median(np=32). Speedups computed from exact median times (unrounded) and rounded to 1 decimal. Speedup vs Serial values are inflated due to the serial/MPI-np=1 anomaly on this hardware — see note below.

**Note on "Speedup vs Serial" values:** The 61.7x and 37.6x numbers are inflated because the serial baseline (19.55 s) is anomalously 2.2x slower than MPI np=1 (~8.7 s) on this hardware. The "Scaling (impl np=1)" column (27.3x, 16.9x) better reflects actual parallel scaling efficiency on this run. See the anomaly section below.

---

## Serial vs MPI np=1 Anomaly

On this hardware, the serial program and MPI implementations at np=1 show a large performance gap:

| Program    | np=1 Time | Ratio vs Serial  |
|------------|-----------|------------------|
| Serial     | 19.553s   | 1.00x (baseline) |
| Column MPI | 8.654s    | 2.26x faster     |
| Row MPI    | 8.809s    | 2.22x faster     |

This 2.2x gap is **not observed** on jobs 8847/8961, where serial ≈ MPI np=1. Possible explanations:

- The serial and MPI binaries are different code paths with different loop structures, memory layouts, and boundary handling; compiler optimizations may behave differently across these source files on this specific hardware
- Memory/cache behavior specific to the Broadwell architecture on these nodes

**This anomaly means "Speedup vs Serial" is inflated for this historical run. The "Scaling (impl np=1)" values are more reliable for assessing parallel efficiency.**

---

## Performance Model Parameters

Measured on this hardware (Broadwell nodes, inter-node communication):

| Parameter | Value              | Description                                                     |
|-----------|--------------------|-----------------------------------------------------------------|
| t_c       | 7.67 ns/cell-update | Per-cell computation cost (from 20x20 grid microbenchmark)     |
| t_s       | 0.404 µs           | MPI startup latency (from ping-pong at smallest message size)  |
| t_w       | 0.125 ns/byte      | Per-byte transfer cost (from large-message asymptotic bandwidth)|

### Caution on t_c

t_c = 7.67 ns is **6.4x faster** than the ~49 ns measured on the jobs 8847/8961 nodes. The microbenchmark uses a tiny 20x20 grid that fits in L1 cache, so t_c is sensitive to cache behavior and hardware. On this run it predicts Column within ~4%, but it does not transfer to the 8847/8961 hardware. **Do not use these values for performance modeling of the 8847/8961 benchmark results.**

---

### Performance Model Formulas

The analytical performance model predicts total time per timestep as:

> Halo exchanges send one value per boundary cell. Implementation uses `MPI_INTEGER` halos (assume 4 bytes/cell for these runs). Formulas use 4 bytes/cell.

**For 1D Row decomposition (p ranks, N×N grid):**

```
T_comp = (N × N / p) × t_c
T_comm = 2 × (t_s + N × 4 × t_w)        # 2 neighbors, each exchanges N cells × 4 bytes/cell (MPI_INTEGER)
T_total = T_comp + T_comm
```

**For 1D Column decomposition (p ranks, N×N grid):**

```
T_comp = (N × N / p) × t_c
T_comm = 2 × (t_s + N × 4 × t_w)        # same formula, but contiguous in Fortran column-major (MPI_INTEGER)
T_total = T_comp + T_comm
```

Note: Row and Column have the same communication volume formula, but their memory access patterns differ. Column halos are contiguous in Fortran's column-major layout, while Row halo data is strided (often requiring packing). This affects memory traffic and packing overhead at the application level, even though the MPI message sizes are identical.

**For 2D Cartesian decomposition (p ranks arranged as √p × √p, N×N grid):**

```
T_comp = (N × N / p) × t_c
T_comm = 4 × (t_s + (N / √p) × 4 × t_w) # 4 neighbors, each exchanges N/√p cells × 4 bytes/cell (MPI_INTEGER)
T_total = T_comp + T_comm
```

The 2D decomposition reduces halo surface area from O(N) to O(N/√p), which is why it outperforms 1D decompositions at high rank counts (lower surface-to-volume ratio).

---

### Model vs Observed

Using this job's parameters over 300 timesteps:

**Column at np=32, N=2048:**

```
T_comp = (2048² / 32) × 7.67 ns × 300 steps = 0.302 s
T_comm = 2 × (0.404 µs + 2048 × 4 × 0.125 ns) × 300 = 0.0009 s
T_predicted = 0.303 s
T_observed  = 0.317 s  →  model is ~4% optimistic (close agreement on this run)
```

**Row at np=32, N=2048:**

```
T_comp = (same formula) = 0.302 s
T_comm = (same formula) = 0.0009 s
T_predicted = 0.303 s
T_observed  = 0.521 s  →  model underpredicts by ~42% relative to observed
```

**Key insight:** The model works well for Column (compute-dominated, contiguous memory access matches t_c measurement) but significantly underpredicts Row. Row halo exchanges involve strided boundary data in Fortran column-major layout, which often requires packing and increases memory traffic relative to Column. This raises the effective per-cell cost beyond the microbench t_c measured on a tiny cache-resident 20x20 kernel. The model's value for Row is in revealing that decomposition choice matters — the simple model assumes identical compute cost, but the gap between predicted and observed shows that memory access patterns have a measurable impact.

---

## Comparison with Later Runs

| Metric                   | Job 7614                       | Job 8847                                          | Job 8961                                         |
|--------------------------|--------------------------------|---------------------------------------------------|--------------------------------------------------|
| Hardware                 | Xeon E5-2650 v4 (Broadwell)    | Newer Hummingbird partition (see job 8847 README) | Newer Hummingbird partition (see job 8961 README)|
| Serial baseline          | 19.553 s                       | 12.121 s                                          | 12.180 s                                         |
| Best speedup (Scaling)   | 27.3x (Column @32)             | 18.4x (2D @16)                                    | 34.9x (2D @32)                                   |
| Implementations tested   | Row, Column                    | All 4                                             | All 4                                            |

Later runs (jobs 8847, 8961) added `mpi_block` and `mpi_2d` implementations:

- **mpi_2d: 34.9x speedup vs serial** on 32 ranks / 2 nodes (see job 8961)

---

## Files

| File             | Description                                                                       |
|------------------|-----------------------------------------------------------------------------------|
| `provenance.txt` | Environment snapshot (hostname, compiler, MPI, SLURM allocation)                 |
| `bench.txt`      | Full benchmark output (all trials, timing breakdown, correctness, rank binding)   |
| `compute.txt`    | Computation microbenchmark (t_c estimation from 20x20 grid, 10000 iterations)    |
| `latency.txt`    | MPI latency/bandwidth microbenchmark (t_s, t_w estimation from ping-pong sweep)  |

---

## Reproduction

```bash
cd MPI_game_of_life
make clean && make all
sbatch scripts/slurm/bench_2n32.slurm
```