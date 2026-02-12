# Benchmark Evidence: Job 8847

## Config
- Nodes: 1
- Tasks: 16
- Grid: 2048x2048
- Steps: 300
- Launcher: `mpirun --bind-to core --map-by core`
- MPI: Open MPI 5.0.5
- Commit (from `provenance.txt`): `unavailable`

## Median Results

| Impl      | np=1    | np=2   | np=4   | np=8   | np=16  | Speedup |
|-----------|---------|--------|--------|--------|--------|---------|
| mpi_2d    | 11.912s | 6.407s | 2.600s | 1.375s | 0.649s | 18.37x  |
| mpi_block | 12.039s | 6.448s | 2.623s | 1.400s | 0.670s | 17.98x  |
| column    | 11.956s | 4.625s | 2.493s | 1.370s | 0.687s | 17.41x  |
| row       | 13.637s | 6.973s | 3.849s | 2.021s | 1.369s | 9.96x   |

Medians are calculated from `bench.txt` using `TOTAL_TIME_SEC` values (3 trials per configuration).
