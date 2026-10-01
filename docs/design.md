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

## Storage model

wrfkit distinguishes storage by lifetime rather than by a particular HPC
filesystem layout.

**Persistent state** belongs with the project by default. This keeps the generic
workflow portable and avoids assuming that a machine provides `/scratch` or
`/lscratch`. The current default remains:

```text
<project>/.wrfkit/
```

Persistent state includes installed WRF/WPS artifacts, reusable downloaded data,
configuration/provenance, and other state that should survive normal temporary
workspace cleanup. Large reusable datasets may later support explicit path
overrides without changing this generic default.

**Disposable state** is high-I/O or reproducible temporary work that can be
recreated safely: build intermediates, staging areas, temporary links, and WPS
working files. A site profile may provide a `scratch_root` for this purpose.
Generic environments should prefer `$TMPDIR` when temporary storage is needed
rather than hard-coding `/tmp`.

The storage split is therefore conceptual:

```text
persistent -> project-local by default
disposable -> site/system scratch when configured
```

A site-specific scratch path must not leak into scientific case configuration.

## MPI policy

The initial WRF build enables MPI and uses Nix-provided OpenMPI. Single-node MPI
is the first validation target.

Generic multi-node MPI portability is not considered solved merely because WRF
compiles with MPI. HPC execution can depend on Slurm, PMIx, UCX, InfiniBand/RDMA,
and site-specific MPI configuration.

## Sapelo2 storage

The default Sapelo2 profile uses a disposable node-local Nix store:

```text
/lscratch/$USER/.nix
```

and declares the site scratch workspace:

```text
scratch_root=/lscratch/$USER/wrfkit
```

The scratch root is for disposable high-I/O work. Persistent wrfkit state remains
project-local by default; wrfkit does not require the repository itself to live
on any particular Sapelo2 filesystem.

The optional shared rootless-Nix profile uses:

```text
/scratch/$USER/.nix
```

The node-local `/lscratch` paths must not be the basis for generic multi-node
MPI assumptions.

## Milestones

- **0.1** WRF 4.8.0, GNU, NetCDF, OpenMPI build, ordinary Linux + Sapelo2 validation.
- **0.2** WPS and first real-data smoke case.
- **0.3** `wrfctl init`, native namelist workflow, provenance manifest.
- **0.4** YAML schema, annotated template, YAML -> namelist generation/validation.
- **0.5+** Slurm backend, site profiles, multi-node MPI, forcing-data acquisition.
