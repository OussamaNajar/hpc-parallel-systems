# Results Summary

Median benchmark results extracted from:
- `results/hummingbird/2026-02-11_job8847/bench.txt`
- `results/hummingbird/2026-02-11_job8961/bench.txt`

Grid: 2048x2048, steps: 300, trials per configuration: 3.

## Key Results - 1 Node

| Impl      | np=1    | np=2   | np=4   | np=8   | np=16  | Speedup(np=16) |
|-----------|---------|--------|--------|--------|--------|----------------|
| mpi_2d    | 11.912s | 6.407s | 2.600s | 1.375s | 0.649s | 18.37x         |
| mpi_block | 12.039s | 6.448s | 2.623s | 1.400s | 0.670s | 17.98x         |
| column    | 11.956s | 4.625s | 2.493s | 1.370s | 0.687s | 17.41x         |
| row       | 13.637s | 6.973s | 3.849s | 2.021s | 1.369s | 9.96x          |

## Key Results - 2 Nodes

| Impl      | np=1    | np=2   | np=4   | np=8   | np=16  | np=32  | Speedup(np=32) |
|-----------|---------|--------|--------|--------|--------|--------|----------------|
| mpi_2d    | 12.148s | 6.551s | 2.597s | 1.383s | 0.656s | 0.349s | 34.85x         |
| mpi_block | 12.122s | 6.548s | 2.624s | 1.396s | 0.664s | 0.350s | 34.59x         |
| column    | 12.074s | 4.713s | 2.520s | 1.351s | 0.667s | 0.360s | 33.51x         |
| row       | 13.732s | 7.053s | 3.911s | 2.030s | 1.147s | 0.593s | 23.16x         |
