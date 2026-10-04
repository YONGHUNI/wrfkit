# wrfkit

`wrfkit` is an experimental reproducible environment and workflow layer for the
[Weather Research and Forecasting (WRF) Model](https://github.com/wrf-model/WRF).

The project is intended for researchers who need WRF but do not want to manage
compiler, MPI, NetCDF, CMake, or Linux-distribution differences manually.

> Hide the system complexity, not the scientific configuration.

**Documentation:** https://yonghuni.github.io/wrfkit/

New to WRF, HPC, or Nix? Start with the [first-run tutorial](https://yonghuni.github.io/wrfkit/tutorials/first-run/). It is written to be usable without prior HPC experience.

## Current status

This repository is an early MVP. The first milestone is deliberately narrow:

- WRF **4.8.0**
- WPS **4.7.0** build integration (build and runtime linkage validated on Sapelo2)
- Linux **x86_64**
- GNU C/C++/Fortran toolchain
- OpenMPI-enabled WRF build
- NetCDF-C / NetCDF-Fortran
- WRF/WPS CMake workflows (`configure_new` / `compile_new`)
- WPS GRIB2 support using the GRIB2 libraries bundled with the pinned WPS source
- normal Nix or rootless Nix on machines without administrator access
- real-data GFS -> WPS -> `real` -> WRF smoke workflow
- single-node MPI on ordinary Linux and UGA Sapelo2
- single-node Slurm execution in both interactive and `sbatch` allocations

Validated configuration foundation:

- TOML `case.toml` configuration and native namelist overlay rendering
- TOML-driven GFS acquisition metadata

Validated high-level workflow:

- `wrfctl plan` / `prep --dry-run` on Lambda Vector and Sapelo2
- `prep` through `real.exe` on Lambda Vector and Sapelo2
- stage-aware WRF MPI decomposition on Sapelo2 (32 available -> 30 safe ranks)
- `wrfctl run` on Sapelo2 with stale-preparation, success-marker, and new-output checks

A fresh high-level `wrfctl run` regression on Lambda Vector remains pending.

Not yet claimed as supported:

- multi-node MPI portability across HPC systems
- general Slurm submission abstraction beyond the validated single-node path
- WRF restart/recovery workflows
- WRF-Chem / WRFDA

Those are planned after the base build has been validated on ordinary Linux and
UGA Sapelo2.

## Documentation

| If you want to... | Start here |
| --- | --- |
| Run wrfkit on one node | [Single-node research guide](docs/single-node-guide.md) |
| See what is and is not validated | [Validation matrix](docs/validation.md) |
| Avoid common HPC/WRF mistakes | [Caveats and safe patterns](docs/caveats.md) |
| Understand the architecture | [Design notes](docs/design.md) |
| Reproduce the included smoke case | [Athens smoke case](cases/athens-smoke/README.md) |

The documentation is intentionally task-first: the README stays short enough to
scan, while detailed procedures, caveats, and implementation notes live in
separate pages.

## Quick start

If Nix is already available:

```bash
git clone git@github.com:YONGHUNI/wrfkit.git
cd wrfkit

./wrfctl doctor
./wrfctl fetch all
./wrfctl build all
```

`wrfctl` enters the pinned Nix development environment automatically. You do
not need to run `nix develop` yourself. Commands and installed WRF binaries can
also be launched without first entering an interactive shell:

```bash
./wrfctl exec ldd .wrfkit/install/wrf-4.8.0/bin/wrf
./wrfctl exec wrf
./wrfctl exec real
```

This matters for rootless Nix: the raw WRF binaries depend on libraries exposed
inside the rootless `/nix/store` namespace. Running those binaries directly from
the host shell can therefore report missing NetCDF/MPI libraries or host glibc
version errors. `wrfctl exec` enters the managed Nix environment first and is
the supported execution path.

To enter the interactive wrfkit environment explicitly:

```bash
./wrfctl shell
```

An interactive Bash prompt is marked with a conda-style `(wrfkit)` suffix, and
installed WRF/WPS binaries are added to `PATH` for that shell session. This is
session-local only; wrfkit does not edit `~/.bashrc`, `~/.profile`, or other
user shell configuration files.

Running `./wrfctl` with no subcommand continues to show the command help rather
than entering a shell implicitly.

### Machine without Nix

Run:

```bash
./bootstrap
```

The wrapper installs rootless Nix through
[`YONGHUNI/rootless-nix-bootstrap`](https://github.com/YONGHUNI/rootless-nix-bootstrap)
when a normal `nix` command is not already available.

The bootstrap wrapper supports configuration profiles and does not require the
user to remember rootless-Nix store paths. Interactive terminal output uses
a shared color convention across `bootstrap` and `wrfctl`: cyan for
headings/information, green for successful checkpoints, yellow for warnings or
automatic adjustments, and red for failures/errors. Redirected/non-interactive
output stays plain. Set `NO_COLOR=1` or
`WRFKIT_COLOR=never` to disable colors, or `WRFKIT_COLOR=always` to force
them. It also manages the rootless Nix lifecycle explicitly:

```bash
./bootstrap --purge
./bootstrap --profile sapelo2 --reset
```

`--purge` removes the currently managed rootless Nix store and exits. `--reset`
removes the managed store and immediately reinstalls it using the requested
profile. Both operations delegate deletion to the pinned `rootless-nix-bootstrap`
`uninstall.sh --purge-store` implementation rather than duplicating uninstall
logic in wrfkit.

## Sapelo2

Do **not** run the first-time environment setup or WRF compilation on an
`ss-sub*` login node. Obtain a compute allocation first, then run the setup from
the compute node.

Example:

```bash
interact -c 16 --mem=64G --time=02:00:00 --gres=lscratch:100

cd ~/work/project/wrfkit
./bootstrap --profile sapelo2
./wrfctl doctor
./wrfctl build all
```

For reproducible/manual use, explicitly selecting `--profile sapelo2` is recommended. If no profile is supplied, `./bootstrap` still attempts Sapelo2 auto-detection as a convenience fallback.

To switch an existing managed rootless Nix installation to this profile in one
step, use:

```bash
./bootstrap --profile sapelo2 --reset
```

This purges the currently managed rootless Nix store first, then recreates it
using `config/bootstrap/sapelo2.conf`.

On Sapelo2, the explicit profile loads the bundled configuration:

```text
config/bootstrap/sapelo2.conf
```

The default Sapelo2 profile now uses the fast, disposable node-local store:

```text
/lscratch/$USER/.nix
```

and declares a separate disposable workspace:

```text
/lscratch/$USER/wrfkit
```

The latter is exposed as `scratch_root` for high-I/O temporary work as WPS and
runtime staging are added. Persistent wrfkit state remains project-local under
`.wrfkit` by default, so the generic project layout does not depend on Sapelo2
filesystem conventions.

This is intentional for the current single-node MVP: the Nix store can be
recreated for each allocation and prioritizes local I/O speed over persistence.

If a shared store is needed later (for example while testing multi-node
workflows), use:

```bash
./bootstrap --profile sapelo2-shared
```

which loads `config/bootstrap/sapelo2-shared.conf` and uses:

```text
/scratch/$USER/.nix
```

A personal override can be stored in:

```text
~/.config/wrfkit/bootstrap.conf
```

For example:

```ini
profile=sapelo2
store_root=/lscratch/$USER/.nix
backend=auto
mpi_launcher=srun
mpi_tasks=auto
```

The same config also carries runtime MPI policy. On a fixed non-Slurm server,
the machine owner can pin a launcher and rank count once:

```ini
profile=my-server
mpi_launcher=mpirun
mpi_tasks=12
```

Supported launchers are `auto`, `srun`, `mpirun`, `mpiexec`, and
`custom`. `auto` chooses `srun` inside an active Slurm allocation and
`mpirun` otherwise. A custom launcher uses `mpi_launcher_command` plus
`mpi_task_flag` (default `-n`). Per-run overrides are available as
`./wrfctl exec ... --ntasks N --launcher NAME`; use `--` before program
arguments if they contain wrfctl option names.

## High-level case workflow

Normal use is intentionally short:

```bash
./wrfctl plan --case athens-smoke   # optional, read-only
./wrfctl prep --case athens-smoke
./wrfctl run  --case athens-smoke
```

`plan` shows the resolved scientific configuration and the stages that will
run without changing files. `prep` prepares the case through `real.exe`, so
its final contract is the existence of `wrfinput_d0*` and `wrfbdy_d01`.
`run` compares the current case with the preparation manifest before launching
`wrf.exe`. Case/namelist changes are reported as warnings and may continue
with the existing prepared inputs; missing prep state or WRF/WPS version drift
remains a hard error.

This follows the project rule: `case.toml` describes **what** experiment is
being run, the native namelists show **what WRF/WPS actually receive**, and
`wrfctl` hides **how** the machine executes the plumbing. The existing
`fetch`/`prepare`/`exec` commands remain first-class low-level primitives
for debugging, teaching, and rerunning one stage.

`./wrfctl prep --case NAME --dry-run` provides the same read-only planning
view as `wrfctl plan`.

On WRF stages, high-level `prep`/`run` also resolve the processor
decomposition against the case dimensions. WRF 4.8 requires each decomposed
patch to contain at least 10 grid cells in both horizontal directions. If an
automatic machine allocation would violate that rule, wrfkit reduces only the
`real`/`wrf` rank count and reports the selected mesh; WPS stages may still
use the full allocation. An explicit unsafe `--ntasks N` is rejected rather
than silently changed.

The current automatic geography path is intentionally limited to the bundled
low-resolution smoke-test dataset, and the current automatic forcing provider is
GFS. Research-grade geography selection remains a separate implementation
target.

Reusable geography and forcing can optionally live outside a repository. Add a
machine-level setting such as:

```ini
data_root=/path/to/shared/wrfkit-data
```

to `~/.config/wrfkit/bootstrap.conf`. Without `data_root`, wrfkit keeps the
existing project-local `.wrfkit/data` behavior.

## Build layout

Generated files are kept outside the tracked source tree. Each case gets one
native WPS/WRF execution workspace under `.wrfkit/work`:

```text
.wrfkit/
├── work/
│   └── <case>/
│       ├── namelist.wps -> cases/<case>/namelist.wps
│       ├── namelist.input -> cases/<case>/namelist.input
│       ├── WPS/WRF runtime links
│       └── generated model products
├── src/
│   ├── WRF-4.8.0/
│   │   └── _build-wrfkit/
│   └── WPS-4.7.0/
│       └── _build-wrfkit/
└── install/
    ├── wrf-4.8.0/
    │   └── bin/
    │       ├── real
    │       └── wrf
    └── wps-4.7.0/
        └── bin/
            ├── geogrid
            ├── ungrib
            └── metgrid
```

The official WRF 4.8.0 release archive is fetched through Nix with its published
SHA-256 digest. This avoids accidentally using GitHub's automatically generated
"Source code" archives, which WRF 4.8.0 explicitly warns do not contain the
mandatory bundled external code required for compilation.

WPS 4.7.0 is pinned to release commit
`5feccecd63384381b6942371c7a837f66e4ccb84` as a non-flake Nix source input.
wrfkit copies that immutable source into `.wrfkit/src` before compilation because
the WPS CMake path can build its bundled GRIB2 libraries in-place. WPS is built
against wrfkit's existing CMake-built WRF installation.

WPS' upstream MPI error behavior is left unchanged. On Slurm, wrfkit instead
isolates MPI-capable programs in their own `srun` child step. This prevents an
`MPI_Abort` from a program such as `geogrid` from cancelling the Slurm step that
hosts an interactive shell.

For single-node Slurm execution, wrfkit creates one child task with N CPUs,
enters the rootless-Nix environment once, and launches N MPI ranks with the
pinned OpenMPI `mpirun`. Interactive shells that already occupy an `srun`
step use `--overlap`; ordinary single-node batch allocations do not. The child
cpuset still limits the job to the CPUs granted by Slurm. Before the inner
`mpirun` starts, wrfkit hides the child step's Slurm resource-manager variables
so OpenMPI does not mistake the single child task for a one-slot allocation.
This avoids one Nix evaluation per MPI rank and keeps all ranks in one
rootless-Nix mount namespace.

MPI-capable `wrfctl exec` commands use a launcher backend. Inside an active
Slurm allocation, `auto` selects the Slurm backend; outside Slurm it selects
the Nix-provided OpenMPI `mpirun`. `mpiexec` and a simple custom launcher are
also supported. The task count may come from the machine profile, the active
Slurm allocation, an environment override, or `--ntasks N`. The single-node
bridge is used for both interactive and batch allocations. Both paths have
been validated on Sapelo2 with WRF completing successfully. Multi-node
rootless-Nix execution remains a separate validation target.

Multi-node rootless Nix still requires a shared store (for example the
`sapelo2-shared` profile) or equivalent per-node environment realization, so
multi-node portability is not yet claimed.

## Commands

```text
./wrfctl doctor                    check the Nix-provided WRF/WPS toolchain
./wrfctl fetch wrf                 materialize pinned WRF 4.8.0 source
./wrfctl fetch wps                 materialize pinned WPS 4.7.0 source
./wrfctl config --case NAME        validate case.toml and update TOML-managed namelist values
./wrfctl config --case NAME --check validate without changing native namelists
./wrfctl plan --case NAME          show resolved science and the workflow plan without changes
./wrfctl prep --case NAME          prepare through real.exe; create wrfinput/wrfbdy
./wrfctl prep --case NAME --dry-run show the plan without changing files
./wrfctl run --case NAME           check prep state, warn on case drift, then run wrf.exe
./wrfctl fetch geog                download low-res mandatory WPS geography for smoke tests
./wrfctl fetch gfs --case NAME     download configured GFS forcing from NOMADS
./wrfctl prepare gfs --case NAME   stage Vtable.GFS and GRIBFILE links
./wrfctl prepare wrf --case NAME   stage WRF runtime tables/data
./wrfctl fetch all                 materialize both software source trees
./wrfctl build wrf --jobs N        build WRF with N parallel jobs
./wrfctl build wps                 build WPS serially against the existing WRF install
./wrfctl build all --jobs N        build WRF with N jobs, then build WPS serially
./wrfctl exec wrf                  run the installed WRF binary with the configured MPI launcher
./wrfctl exec wrf --ntasks 12       override the MPI rank count for this run
./wrfctl exec wrf --launcher mpirun select a launcher explicitly for this run
./wrfctl exec real                 run the installed real binary with the configured MPI launcher
./wrfctl exec geogrid              run the installed WPS geogrid binary
./wrfctl exec geogrid --case NAME  run geogrid from cases/NAME
./wrfctl exec ungrib --case NAME   run ungrib from cases/NAME
./wrfctl exec metgrid --case NAME  run metgrid from cases/NAME
./wrfctl exec CMD ...              run any command inside the pinned Nix environment
./wrfctl clean                     remove generated WRF/WPS build/install files
./wrfctl shell                     enter the interactive wrfkit environment
```

`wrfctl build wps` requires a completed wrfkit WRF installation. Use
`wrfctl build all` for a clean WRF -> WPS build sequence. Inside a Slurm allocation, `wrfctl exec` isolates MPI-capable WRF/WPS
programs in a child step; serial utilities continue to run directly in the
current environment. In an `sbatch` job, `mpi_tasks=auto` uses
`SLURM_NTASKS`. For a single-node batch allocation, wrfkit reserves that many
CPUs in one child task and runs the requested ranks with the pinned OpenMPI
launcher inside one Nix namespace. In an interactive `srun` shell that
occupies one task, `mpi_tasks=auto` can use `SLURM_CPUS_PER_TASK` and uses
the same bridge with `--overlap`. The WPS build enables
MPI for geogrid/metgrid and GRIB2 support. WPS itself is compiled serially:
the pinned WPS 4.7.0 CMake build can race when parallel targets write shared
Fortran module files such as `filelist.mod` and `gridinfo.mod`.
The included `athens-smoke` case
now validates the real-data path through geography, GFS forcing, Vtable
selection, WPS staging, `real`, and `wrf`. This smoke case validates the
workflow, not the scientific suitability of its configuration for research.

The source tree is preserved by `clean`; use `rm -rf .wrfkit/src` when a complete
source reset is needed.

### First real-data smoke case

The repository includes `cases/athens-smoke`, a one-domain 12 km geogrid smoke
case centered near Athens, Georgia. Fetch the official NCAR low-resolution
mandatory geography package and run geogrid with:

```bash
./wrfctl fetch geog
./wrfctl exec geogrid --case athens-smoke
```

The geography is stored persistently at
`.wrfkit/data/geog/low-res-mandatory`, while the downloaded archive is cached
under `.wrfkit/cache`. The low-resolution package is for testing/education
only; production or research simulations should use the appropriate
higher-resolution static datasets.

A successful geogrid run creates
`.wrfkit/work/athens-smoke/geo_em.d01.nc`. Native `geogrid.log` is collected
under `.wrfkit/logs/athens-smoke/<run-id>/`. The tracked
`cases/athens-smoke` directory remains configuration-only; wrfkit changes only
its own child-process working directory, not the user's shell directory.

The next smoke stage uses a fixed 2026-09-30 00Z GFS cycle and f000/f003/f006
files, regionally subset through the NOAA/NCEP NOMADS GFS 0.25-degree GRIB
filter:

```bash
./wrfctl fetch gfs --case athens-smoke
./wrfctl prepare gfs --case athens-smoke
./wrfctl exec ungrib --case athens-smoke
```

Downloaded forcing is cached under `.wrfkit/data/gfs/<date>/<cycle>/<request-key>/atmos`.
`prepare gfs` places only symlinks to those files and the pinned WPS
`Vtable.GFS` in `.wrfkit/work/<case>`.

### Case-scoped execution logs

Native WPS/WRF logs are snapshotted after each supported execution. The native
files remain in the generated workspace, where WRF/WPS naturally reuse their
fixed filenames. Persistent provenance stores one archive per run instead of
renaming every native log file individually:

```text
.wrfkit/logs/
└── <case>/
    └── YYYYMMDD_HHMMSS_<program>/
        ├── command.txt
        ├── run.env
        ├── run.started
        └── native-logs.tar
```

Only native log files modified after `run.started` are included. This prevents
stale RSL files from a previous run with a larger MPI rank count from being
mixed into the current archive and avoids pathological per-file rename latency
on some shared HPC filesystems.

The case name is resolved in this order:

1. `WRFKIT_CASE_NAME`, when explicitly set;
2. the first path component below `cases/` for a future `cases/<name>/...` layout;
3. `default` when running from the repository root;
4. otherwise, the current working directory name.

Scientific outputs such as `geo_em*`, `met_em*`, `wrfinput*`, `wrfbdy*`,
and `wrfout*` remain in `.wrfkit/work/<case>`. Native diagnostic logs also
remain there as reusable working files, while the run-specific snapshot is
stored in `native-logs.tar`. The tracked `cases/<case>` tree remains the
source of truth for scientific configuration.

## Reproducibility boundary

The current MVP pins:

- the nixpkgs Git revision in `flake.nix`;
- the WRF release version and release-archive SHA-256;
- the WPS 4.7.0 release commit;
- the WRF/WPS CMake configurations used by the build scripts.

Nix does **not** make the host kernel, Slurm, network fabric, or HPC interconnect
reproducible. Multi-node MPI integration therefore remains a separate validation
task for each HPC backend.

## Case configuration model

Each case now has one wrfkit configuration file:

```text
cases/<name>/
├── case.toml
├── namelist.wps
└── namelist.input
```

`case.toml` owns wrfkit-specific settings such as forcing acquisition and may
also manage common WPS/WRF namelist values. With
`[namelist] managed = true`, `wrfctl config` overlays TOML-owned values
onto the native namelists and leaves every unspecified native setting intact.
With `managed = false`, wrfkit never modifies either native namelist.

For maximum freedom, arbitrary native namelist groups and keys can be placed
under `[advanced.wps.<group>]` and `[advanced.wrf.<group>]`. A raw escape
hatch is also available for unusual Fortran syntax.

See [`docs/design.md`](docs/design.md) and the
[`case.toml` reference](docs/reference/case-toml.md).


### WRF real-data preparation boundary

At the high level, `prep` means "make this case ready for `wrf.exe`".
It therefore includes the native `real.exe` stage and verifies that
`wrfinput_d0*` and `wrfbdy_d01` were created.

The native stages remain directly callable:

```bash
./wrfctl prepare wrf --case athens-smoke
./wrfctl exec real --case athens-smoke
./wrfctl exec wrf --case athens-smoke
```

Using the high-level pair adds a preparation manifest. `run` reports when the
TOML or native namelists changed after prep, while leaving the decision to reuse
the existing prepared inputs visible to the researcher:

```bash
./wrfctl prep --case athens-smoke
./wrfctl run  --case athens-smoke
```
