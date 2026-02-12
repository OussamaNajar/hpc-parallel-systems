# Local Testing Report v7

## Serial Initialization Pattern
`serial.f90` initializes a haloed grid (`grid(0:N+1,0:N+1)`) to zero, then rank-independent deterministic seed:

- `if (N >= 3) then`
- `grid(1,3) = 1`
- `grid(2,1) = 1`
- `grid(2,3) = 1`
- `grid(3,2) = 1`
- `grid(3,3) = 1`
- `end if`

All MPI implementations now use the same pattern on rank 0 via `full_init` broadcast and local extraction with `idx = (j-1)*N + i`.

## Ground Truth (N=64)
serial: ALIVE_FINAL=5 CHECKSUM_FINAL=22000092

## Ground Truth (N=100, remainder test)
serial: ALIVE_FINAL=5 CHECKSUM_FINAL=22000092

## Partitioning Formulas Used
| Impl       | my_i_start                           | my_j_start                           | my_local_rows                    | my_local_cols                    |
|------------|--------------------------------------|--------------------------------------|----------------------------------|----------------------------------|
| row        | 1 + rank*base_rows + min(rank,rem_rows) | 1                                | base_rows + merge(1,0,rank<rem_rows) | N                           |
| column     | 1                                    | 1 + rank*base_cols + min(rank,rem_cols) | N                            | base_cols + merge(1,0,rank<rem_cols) |
| mpi_block  | 1 + proc_i*base_i + min(proc_i,rem_i) | 1 + proc_j*base_j + min(proc_j,rem_j) | base_i + merge(1,0,proc_i<rem_i) | base_j + merge(1,0,proc_j<rem_j) |
| mpi_2d     | 1 + coords(1)*base_i + min(coords(1),rem_i) | 1 + coords(2)*base_j + min(coords(2),rem_j) | base_i + merge(1,0,coords(1)<rem_i) | base_j + merge(1,0,coords(2)<rem_j) |

## Correctness (N=64, np=1)
| Impl       | ALIVE | CHECKSUM | Match |
|------------|-------|----------|-------|
| row        | 5     | 22000092 | YES   |
| column     | 5     | 22000092 | YES   |
| mpi_block  | 5     | 22000092 | YES   |
| mpi_2d     | 5     | 22000092 | YES   |

## Correctness (N=64, np=4)
| Impl       | ALIVE | CHECKSUM | Match |
|------------|-------|----------|-------|
| row        | 5     | 22000092 | YES   |
| column     | 5     | 22000092 | YES   |
| mpi_block  | 5     | 22000092 | YES   |
| mpi_2d     | 5     | 22000092 | YES   |

## Correctness (N=100, np=3) - REMAINDER TEST
| Impl       | ALIVE | CHECKSUM | Match |
|------------|-------|----------|-------|
| row        | 5     | 22000092 | YES   |
| column     | 5     | 22000092 | YES   |
| mpi_block  | 5     | 22000092 | YES   |
| mpi_2d     | 5     | 22000092 | YES   |

## Ownership Check: PASSED
## mpi_2d periods=.false.: VERIFIED (`periods(1)=F`, `periods(2)=F` in runtime output)
## Issues Found:
- No correctness mismatches in local tests.
- Local oversubscribed MPI runs are communication-dominated; this is expected for small N and does not affect checksum correctness.
## Ready for Hummingbird: YES
