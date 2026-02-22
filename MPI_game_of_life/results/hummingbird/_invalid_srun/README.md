# Invalid Benchmark Runs (Archived)

These runs used `srun` as the MPI launcher, which caused all MPI programs 
to report `MPI Ranks: 1` regardless of the requested np value.

## Root Cause

When using `srun -n <np>` without proper `--mpi=` plugin configuration,
each executable launches as an independent single-rank job instead of
a coordinated MPI application.

## Affected Jobs

- **job8292**: 2-node run, all sections show `MPI Ranks: 1`
- **job8306**: 2-node run, all sections show `MPI Ranks: 1`

## Fix Applied

Subsequent runs use `mpirun` with explicit binding:
```bash
export USE_SRUN=0
export BIND_FLAGS="--bind-to core --map-by core --report-bindings"
mpirun -np $np $BIND_FLAGS ./bin/mpi_2d ...
```


