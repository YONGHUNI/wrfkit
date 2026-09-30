# wrfkit design notes

## Scope boundary

wrfkit separates three concerns:

1. **Software environment** — Nix pins compiler, MPI, NetCDF, CMake, WRF, and eventually WPS.
2. **Scientific configuration** — YAML or native Fortran namelists.
3. **Execution backend** — local execution, Slurm, and site-specific MPI integration.

> Hide the system complexity, not the scientific configuration.

## Planned configuration modes

Case initialization will eventually ask:

```text
How would you like to configure WRF?

  1) YAML configuration
     Edit case.yaml.
     namelist.wps and namelist.input are generated automatically.

  2) Native WRF namelists
     Edit namelist.wps and namelist.input directly.

Select [1/2]:
```

YAML mode should expose WRF scientific options rather than replacing them with
opaque presets. A schema should define defaults, comments, allowed values, type
checks, validation, full-template generation, and native namelist generation.

Native mode treats `namelist.wps` and `namelist.input` as the source of truth.

## MPI policy

The initial WRF build enables MPI and uses Nix-provided OpenMPI. Single-node MPI
is the first validation target.

Generic multi-node MPI portability is not considered solved merely because WRF
compiles with MPI. HPC execution can depend on Slurm, PMIx, UCX, InfiniBand/RDMA,
and site-specific MPI configuration.

## Sapelo2 storage

Default shared profile:

```text
/scratch/$USER/.nix
```

Explicit single-node local-I/O profile:

```text
/lscratch/$USER/.nix
```

The latter is node-local and must not be the basis for generic multi-node MPI.

## Milestones

- **0.1** WRF 4.8.0, GNU, NetCDF, OpenMPI build, ordinary Linux + Sapelo2 validation.
- **0.2** WPS and first real-data smoke case.
- **0.3** `wrfctl init`, native namelist workflow, provenance manifest.
- **0.4** YAML schema, annotated template, YAML -> namelist generation/validation.
- **0.5+** Slurm backend, site profiles, multi-node MPI, forcing-data acquisition.
