# Validation matrix

This page records what has been empirically exercised, separate from what is
merely implemented or planned.

## Current support boundary

| Capability | Status | Notes |
| --- | --- | --- |
| WRF 4.8.0 build | Validated | CMake workflow, GNU toolchain |
| WPS 4.7.0 build | Validated | Built against the wrfkit WRF installation |
| Rootless Nix on Sapelo2 | Validated | Default single-node profile uses node-local `/lscratch` |
| Static geography staging | Validated | Bundled low-resolution smoke-test geography |
| GFS acquisition/staging | Validated | Fixed GFS smoke window through NOMADS |
| `geogrid -> ungrib -> metgrid` | Validated | `athens-smoke` |
| `real -> wrf` | Validated | Produces WRF input/boundary/output files |
| Single-node interactive MPI | Validated | Tested with 16 and 24 ranks during development |
| Single-node `sbatch` MPI | Validated | 16-rank Sapelo2 run completed successfully |
| One-Nix-namespace Slurm bridge | Validated | Inner OpenMPI launch confirmed in batch |
| Per-run native log archive | Validated | `native-logs.tar` with current-run filtering |
| Multi-node MPI | Not validated | Do not treat as supported research execution |
| WRF restart/recovery workflow | Not validated | Requires dedicated workflow testing |
| Scratch-backed execution workspace | Not implemented | `scratch_root` is currently configuration metadata |
| YAML case frontend | Planned | Native namelists remain the source of truth |

## Single-node Slurm validation

The validated batch topology is:

```text
Slurm allocation: 1 node, N CPUs
        |
        v
one child srun task with N CPUs
        |
        v
one rootless-Nix namespace entry
        |
        v
pinned OpenMPI: mpirun -np N
        |
        v
WRF MPI ranks
```

A Sapelo2 16-rank batch validation on an Intel Xeon Gold 6130 node completed
with Slurm state `COMPLETED`, exit code `0:0`, and WRF reporting
`SUCCESS COMPLETE WRF`.

The observed wall time of individual smoke runs is intentionally not treated as
a benchmark. Short runs are sensitive to node state, filesystem metadata/cache
state, Nix evaluation caches, and other shared-system effects.

## What "validated" means here

Validated means that the path has been executed end-to-end in the stated
environment and produced the expected program-level result. It does not mean:

- every possible WRF namelist option is supported;
- every HPC site will behave identically;
- the smoke-case scientific configuration is recommended;
- numerical results are scientifically validated for a particular study.

## Validation checklist for a new research case

Before treating a new case as production-ready, confirm the workflow and the
science separately.

Workflow checks:

```text
geogrid completes
ungrib completes
metgrid completes
real creates wrfinput/wrfbdy
wrf reports SUCCESS COMPLETE WRF
expected wrfout files exist
provenance archive exists
```

Scientific checks should be defined by the study: domain adequacy, forcing,
physics, spin-up, stability, expected fields, and comparison against suitable
observations or reference data.
