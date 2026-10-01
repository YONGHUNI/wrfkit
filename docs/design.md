# wrfkit design notes

## Scope boundary

wrfkit separates three concerns:

1. **Software environment** — Nix pins compiler, MPI, NetCDF, CMake, WRF, and WPS.
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

## WPS build policy

wrfkit pins WPS 4.7.0 to release commit
`5feccecd63384381b6942371c7a837f66e4ccb84`. The WPS source is provided as a
non-flake Nix input and copied into project-local state before building.

The CMake workflow is used for both WRF and WPS. WPS is built only after a
CMake-built WRF installation exists, with:

```text
WRF 4.8.0
   ↓
WPS 4.7.0
   ├─ geogrid
   ├─ ungrib
   └─ metgrid
```

The initial WPS build enables MPI for geogrid/metgrid and enables GRIB2 by
building the zlib/libpng/Jasper sources bundled with the pinned WPS release.
This avoids coupling the build to whatever Jasper ABI a generic host happens to
provide.

Build integration is separate from the future real-data workflow. Geographic
datasets, meteorological forcing, Vtable selection, `namelist.wps`, and WPS
working-directory staging will be added on top of this build layer.

## MPI policy

The initial WRF build enables MPI and uses Nix-provided OpenMPI. WPS
`geogrid`/`metgrid` are also built with MPI. Single-node MPI remains the first
validated execution target.

WRF/WPS source error semantics are not modified to protect an interactive shell.
Instead, execution isolation belongs to the scheduler backend. When
`wrfctl exec` is used inside a Slurm allocation, MPI-capable programs are
launched in a separate `srun` child step:

```text
interactive Slurm step
└─ shell
   └─ wrfctl
      └─ child srun step
         └─ MPI program
```

If the shell itself is already running in an `srun` step, wrfkit adds
`--overlap` so the child step can coexist with it. An `MPI_Abort` then tears
down the child step instead of the step hosting the interactive shell.

A Slurm child step may be created outside the rootless-Nix mount namespace of
its parent. The child therefore re-enters wrfkit's Nix environment before
starting the WRF/WPS binary rather than inheriting a raw `/nix/store` path.

The current `exec` launcher deliberately uses one MPI task. This is a
single-rank execution and smoke-test path, not a multi-node topology decision.
Future multi-node support should extend the Slurm backend with explicit
`--nodes`, `--ntasks`, task placement, and site-specific MPI/PMIx settings
without changing WRF/WPS source code.

The default Sapelo2 rootless-Nix store under `/lscratch` is node-local and
therefore cannot be assumed to exist on additional nodes. Multi-node execution
must use a shared store such as the `sapelo2-shared` profile, or realize an
equivalent environment independently on every participating node.

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
- **0.2** WPS 4.7.0 build integration and first real-data smoke case.
- **0.3** `wrfctl init`, native namelist workflow, provenance manifest.
- **0.4** YAML schema, annotated template, YAML -> namelist generation/validation.
- **0.5+** Slurm backend, site profiles, multi-node MPI, forcing-data acquisition.
