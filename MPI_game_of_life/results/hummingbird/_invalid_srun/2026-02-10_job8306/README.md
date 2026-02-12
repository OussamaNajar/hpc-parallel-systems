# Benchmark Evidence: Job 8306

## Summary
Scaling proof run (32 ranks) on Hummingbird cluster.

## Configuration
| Parameter | Value |
|-----------|-------|
| Job ID | 8306 |
| Date | 2026-02-10 |
| Nodes | 2 |
| Node List | node-[09,18] |
| Tasks | 32 |
| Grid | 2048x2048 |
| Steps | 300 |
| Reps | 3 |
| NP Sweep | 1 2 4 8 16 32 |
| Launcher | srun |

## Software
| Component | Version |
|-----------|---------|
| MPI | mpirun (Open MPI) 5.0.5 |
| Compiler | GNU Fortran (GCC) 13.2.0 |

## Files
- `provenance.txt` - Environment snapshot and SLURM allocation
- `bench.txt` - Full benchmark output (timing, correctness)
- `compute.txt` - Computation microbenchmark
- `latency.txt` - MPI latency microbenchmark
- `stdout.txt.gz` - Compressed run transcript

## Reproduction
```bash
cd ~/hpc-parallel-systems/MPI_game_of_life
sbatch scripts/slurm/bench_2n32.slurm
```
