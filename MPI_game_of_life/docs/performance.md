# Performance Model

Results were checked against curated job 8961 (34.85x on 32 cores across 2 nodes).
See `results/hummingbird/2026-02-11_job8961/`.

Historical launch diagnostics are kept in `results/hummingbird/_invalid_srun/`.
Those logs document an earlier `srun` issue and are not used for current performance results.

## Latest Results (Job 8961)

| np | Time (s) | Speedup | Efficiency |
|----|----------|---------|------------|
| 1  | 12.15    | 1.0x    | 100% |
| 4  | 2.59     | 4.7x    | 117% |
| 16 | 0.66     | 18.4x   | 115% |
| 32 | 0.35     | 34.85x   | 108% |

## Measured Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| t_c | 7.67 ns | Per-cell update |
| t_s | 0.404 us | MPI startup latency |
| t_w | 0.125 ns/byte | Transfer time |

## Analytical Model

```text
T(p) ~= (N^2/p)*t_c + 2*(N/p)*t_s + 2*(N/p)*8*t_w
```

For 2048^2 and 32 ranks, the model predicts 1.07s and the observed runtime is 0.35s.
