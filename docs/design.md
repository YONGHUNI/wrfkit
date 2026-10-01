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

## Case and log model

Execution logs are persistent provenance rather than disposable scratch data.
wrfkit therefore collects native WPS/WRF diagnostic logs under:

```text
<project>/.wrfkit/logs/<case>/<run-id>/
```

A run directory records the invoked command, working directory, exit status,
Slurm job/step identifiers when available, and the native program logs. WPS logs
(`geogrid.log*`, `metgrid.log*`, `ungrib.log`) and WRF RSL logs
(`rsl.out.*`, `rsl.error.*`) are moved there after execution. Model products
and scientific inputs remain in the case working directory.

Until `wrfctl init` establishes a first-class case manifest, `wrfctl exec`
accepts `--case NAME` and resolves it to `cases/NAME`. wrfkit changes the
working directory only inside its own process, so users can launch case commands
from the repository root while WPS/WRF still see native relative paths such as
`namelist.wps`, `GEOGRID.TBL`, and future forcing links. The selected case name
is also exported as `WRFKIT_CASE_NAME` so execution logs are routed to
`.wrfkit/logs/NAME`.

Without `--case`, case identity continues to fall back to `WRFKIT_CASE_NAME`,
a `cases/<name>/...` current path, or the current working directory.
Repository-root executions without a selected case use the transitional name
`default`.

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

Build integration is separate from the future real-data workflow. The first
real-data milestone starts with a geogrid-only `athens-smoke` case. Its
low-resolution mandatory WPS geography is downloaded into persistent state at
`.wrfkit/data/geog/low-res-mandatory`; the source archive is cached separately
under `.wrfkit/cache`. This low-resolution dataset is a validation fixture, not
a production-data default.

The smoke case keeps its native `namelist.wps` tracked under
`cases/athens-smoke` and selects the `lowres` resolution defined by WPS
4.7.0's `GEOGRID.TBL.ARW`.

The first forcing path is GFS 0.25-degree data from NOAA/NCEP NOMADS. Case-level
forcing metadata is tracked in `forcing.conf`. `wrfctl fetch gfs --case NAME`
stores reusable GRIB2 files under persistent `.wrfkit/data/gfs`, while
`wrfctl prepare gfs --case NAME` creates case-local `Vtable` and
`GRIBFILE.???` symlinks without duplicating the forcing data. The initial
Athens smoke case deliberately uses a fixed short NOMADS window; because NOMADS
is a rolling operational service, a durable archived forcing backend remains a
future reproducibility improvement.

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
