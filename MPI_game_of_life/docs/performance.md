# Performance Model

Results were checked against curated job 8961 (34.9x vs serial, 34.85x self-scaling, on 32 cores across 2 nodes).
See `results/hummingbird/2026-02-11_job8961/`.

Historical launch diagnostics are kept in `results/hummingbird/_invalid_srun/`.
Those logs document an earlier `srun` issue and are not used for current performance results.

## Latest Results (Job 8961)

| np | Time (s) | Scaling (impl np=1) | Efficiency |
|----|----------|---------------------|------------|
| 1  | 12.15    | 1.0x    | 100% |
| 4  | 2.59     | 4.7x    | 117% |
| 16 | 0.66     | 18.4x   | 115% |
| 32 | 0.35     | 34.85x              | 108% |

## Measured Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_c | 7.67 ns | Per-cell update (Broadwell hardware, job 7614 — see job READMEs for hardware-specific values) |
| t_s | 0.404 us | MPI startup latency |
| t_w | 0.125 ns/byte | Transfer time |

## Analytical Model

```text
T(p) ~= (N^2/p)*t_c + 2*(N/p)*t_s + 2*(N/p)*4*t_w
```

For 2048^2 and 32 ranks, the model predicts 1.07s and the observed runtime is 0.35s.

> **Note:** The model overpredicts by ~3x. The microbenchmark t_c is derived from a 20×20 grid — too small for compiler vectorization to engage. The actual 2048×2048 application benefits from these optimizations, yielding a much lower effective per-cell cost. The equation above is a simplified 1D halo sketch, not a full derivation (not absolute prediction). See per-job READMEs for decomposition-specific formulas.
