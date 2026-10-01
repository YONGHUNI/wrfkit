# wrfkit

`wrfkit` is an experimental reproducible environment and workflow layer for the
[Weather Research and Forecasting (WRF) Model](https://github.com/wrf-model/WRF).

The project is intended for researchers who need WRF but do not want to manage
compiler, MPI, NetCDF, CMake, or Linux-distribution differences manually.

> Hide the system complexity, not the scientific configuration.

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
- single-node MPI as the initial execution target

Not yet claimed as supported:

- WPS real-data preparation/data-acquisition workflow
- automated `namelist.wps` / `namelist.input` generation
- YAML configuration frontend
- multi-node MPI portability across HPC systems
- general Slurm submission abstraction and validated multi-node MPI
- WRF-Chem / WRFDA

Those are planned after the base build has been validated on ordinary Linux and
UGA Sapelo2.

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
user to remember rootless-Nix store paths. It also manages the rootless Nix
lifecycle explicitly:

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
```

## Build layout

Generated files are kept outside the tracked source tree:

```text
.wrfkit/
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
hosts an interactive shell. The child step re-enters the wrfkit Nix environment
before executing the binary, which is required for rootless-Nix setups where a
new Slurm step does not share the parent's mount namespace.

The current `wrfctl exec` path intentionally launches one MPI task; it is a
single-rank execution/smoke-test path, not a multi-node scheduler policy. Future
multi-node execution will parameterize task/node topology in the Slurm backend
rather than modifying WRF/WPS source behavior. Multi-node rootless Nix will also
require a shared store (for example the `sapelo2-shared` profile) or equivalent
per-node environment realization.

## Commands

```text
./wrfctl doctor                    check the Nix-provided WRF/WPS toolchain
./wrfctl fetch wrf                 materialize pinned WRF 4.8.0 source
./wrfctl fetch wps                 materialize pinned WPS 4.7.0 source
./wrfctl fetch geog                download low-res mandatory WPS geography for smoke tests
./wrfctl fetch gfs --case NAME     download configured GFS forcing from NOMADS
./wrfctl prepare gfs --case NAME   stage Vtable.GFS and GRIBFILE links
./wrfctl fetch all                 materialize both software source trees
./wrfctl build wrf --jobs N        build WRF with N parallel jobs
./wrfctl build wps --jobs N        build WPS against the existing WRF install
./wrfctl build all --jobs N        build WRF, then WPS, with N parallel jobs
./wrfctl exec wrf                  run the installed WRF binary in the Nix environment
./wrfctl exec real                 run the installed real binary in the Nix environment
./wrfctl exec geogrid              run the installed WPS geogrid binary
./wrfctl exec geogrid --case NAME  run geogrid from cases/NAME
./wrfctl exec ungrib --case NAME   run ungrib from cases/NAME
./wrfctl exec metgrid --case NAME  run metgrid from cases/NAME
./wrfctl exec CMD ...              run any command inside the pinned Nix environment
./wrfctl clean                     remove generated WRF/WPS build/install files
./wrfctl shell                     enter the interactive wrfkit environment
```

`wrfctl build wps` requires a completed wrfkit WRF installation. Use
`wrfctl build all` for a clean WRF -> WPS build sequence. Inside a Slurm
allocation, `wrfctl exec` launches MPI-capable WRF/WPS programs in an isolated
one-task `srun` step; serial utilities continue to run directly in the current
environment. The WPS build enables
MPI for geogrid/metgrid and GRIB2 support, while a real-data WPS workflow
(`namelist.wps`, geography, forcing, Vtable selection, and staging) remains the
next milestone and is not yet claimed as validated.

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

A successful geogrid run creates `geo_em.d01.nc` in the case directory. Native
`geogrid.log` is collected under `.wrfkit/logs/athens-smoke/<run-id>/`.
The command may be launched from the repository root; wrfkit changes only its
own child-process working directory, not the user's shell directory.

The next smoke stage uses a fixed 2026-09-30 00Z GFS cycle and f000/f003/f006
files, regionally subset through the NOAA/NCEP NOMADS GFS 0.25-degree GRIB
filter:

```bash
./wrfctl fetch gfs --case athens-smoke
./wrfctl prepare gfs --case athens-smoke
./wrfctl exec ungrib --case athens-smoke
```

Downloaded forcing is cached under `.wrfkit/data/gfs/<date>/<cycle>/atmos`.
The case keeps only symlinks to those files and to the pinned WPS
`Vtable.GFS`.

### Case-scoped execution logs

Native WPS/WRF logs are collected after each supported execution instead of
being left in the case working directory. The persistent layout is:

```text
.wrfkit/logs/
└── <case>/
    └── YYYYMMDD_HHMMSS_<program>/
        ├── command.txt
        ├── run.env
        ├── geogrid.log / metgrid.log / ungrib.log
        └── rsl.out.* / rsl.error.*
```

The case name is resolved in this order:

1. `WRFKIT_CASE_NAME`, when explicitly set;
2. the first path component below `cases/` for a future `cases/<name>/...` layout;
3. `default` when running from the repository root;
4. otherwise, the current working directory name.

If matching native logs already exist before a run, wrfkit preserves them under
that run's `preexisting/` directory before launching the new program. Scientific
outputs such as `geo_em*`, `met_em*`, `wrfinput*`, `wrfbdy*`, and
`wrfout*` remain in the case/work directory; only native diagnostic logs are
collected.

## Reproducibility boundary

The current MVP pins:

- the nixpkgs Git revision in `flake.nix`;
- the WRF release version and release-archive SHA-256;
- the WPS 4.7.0 release commit;
- the WRF/WPS CMake configurations used by the build scripts.

Nix does **not** make the host kernel, Slurm, network fabric, or HPC interconnect
reproducible. Multi-node MPI integration therefore remains a separate validation
task for each HPC backend.

## Planned configuration model

The planned workflow will support two first-class scientific-configuration modes
when a case is initialized:

```text
1) YAML frontend
   case.yaml -> generated namelist.wps + namelist.input

2) Native WRF configuration
   edit namelist.wps + namelist.input directly
```

Both modes will converge on the same WPS/WRF execution pipeline. YAML mode is
intended to expose WRF's scientific configuration rather than hide it: defaults,
documentation, validation, and comments will be generated from a schema, while
the final native namelist files will always be preserved for provenance.

See [`docs/design.md`](docs/design.md) for the working design notes.
