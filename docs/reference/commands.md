# wrfctl command reference

Commands below are run from the repository root unless noted otherwise.

## High-level case workflow

| Command | Purpose |
| --- | --- |
| `./wrfctl config --case NAME` | Validate `case.toml` and update TOML-managed values in the native namelists |
| `./wrfctl config --case NAME --check` | Validate TOML/native mapping without writing namelist files |
| `./wrfctl plan --case NAME` | Show resolved scientific configuration, input-cache state, and planned stages without changes |
| `./wrfctl prep --case NAME --dry-run` | Show the same read-only preparation plan |
| `./wrfctl prep --case NAME` | Prepare through `geogrid -> ungrib -> metgrid -> real`; verify `wrfinput`/`wrfbdy` |
| `./wrfctl run --case NAME` | Verify the prep manifest, run WRF, and require a current success marker/output |
| `./wrfctl exec real --case NAME` | Low-level direct `real.exe` execution |
| `./wrfctl exec wrf --case NAME` | Low-level direct `wrf.exe` execution |

`prep` + `run` is the normal orchestration layer. The lower-level commands below remain
available when you want to inspect, teach, debug, or rerun only one stage.

Current automatic `prep` support is deliberately narrow: bundled
`geog_data_res='lowres'` geography and GFS forcing. Other static-geography
packages should continue to use the lower-level workflow until a
research-grade geography selector is implemented.

## Environment and build

| Command | Purpose |
| --- | --- |
| `./wrfctl doctor` | Check the Nix-provided WRF/WPS toolchain |
| `./wrfctl shell` | Enter an interactive wrfkit shell |
| `./wrfctl fetch wrf` | Materialize the pinned WRF source |
| `./wrfctl fetch wps` | Materialize the pinned WPS source |
| `./wrfctl fetch all` | Materialize both source trees |
| `./wrfctl build wrf --jobs N` | Build WRF with N parallel jobs |
| `./wrfctl build wps` | Build WPS serially against wrfkit WRF |
| `./wrfctl build all --jobs N` | Build WRF with N jobs, then WPS serially |
| `./wrfctl clean` | Remove generated build/install files managed by wrfkit |

## Real-data preparation

| Command | Purpose |
| --- | --- |
| `./wrfctl fetch geog` | Download low-resolution geography used by the smoke test |
| `./wrfctl fetch gfs --case NAME` | Download GFS forcing configured by a case |
| `./wrfctl prepare gfs --case NAME` | Stage Vtable.GFS and GRIBFILE links |
| `./wrfctl exec geogrid --case NAME` | Create the model-domain geography |
| `./wrfctl exec ungrib --case NAME` | Decode staged GRIB forcing |
| `./wrfctl exec metgrid --case NAME` | Interpolate forcing to the model grid |
| `./wrfctl prepare wrf --case NAME` | Stage WRF runtime tables/data |
| `./wrfctl exec real --case NAME` | Create WRF initial/boundary files |
| `./wrfctl exec wrf --case NAME` | Run WRF |

## MPI overrides

```bash
./wrfctl exec wrf --case NAME --ntasks 12
./wrfctl exec wrf --case NAME --launcher mpirun
```

Supported launcher names are `auto`, `srun`, `mpirun`, `mpiexec`, and
`custom`.

On the validated single-node Slurm path, the profile normally uses `srun`
as the outer backend and wrfkit launches the actual MPI ranks with its pinned
OpenMPI inside one Nix namespace.

## Run any command inside the environment

```bash
./wrfctl exec CMD ...
```

Example:

```bash
./wrfctl exec ldd .wrfkit/install/wrf-4.8.0/bin/wrf
```

Running raw WRF binaries directly from the host shell is not the supported
rootless-Nix path.

## Build parallelism

`--jobs N` controls WRF compilation. WPS 4.7.0 is built with one job even
when `build all --jobs N` is used. The pinned WPS CMake build can race when
parallel targets write shared Fortran module files (notably `filelist.mod`
and `gridinfo.mod`), so wrfkit uses serial WPS compilation for reliability.


## Shared reusable data

By default, downloaded data remains project-local under `.wrfkit/data`.
To reuse static geography and forcing across multiple wrfkit clones, add a
machine-level data root to `~/.config/wrfkit/bootstrap.conf`:

```ini
data_root=/path/to/shared/wrfkit-data
```

`WRFKIT_DATA_ROOT` or `WRFKIT_DATA_DIR` can override this for a process.
The case workspace remains project-local under `.wrfkit/work/<case>`; only
reusable downloaded inputs move to the shared data root.

GFS cache directories include a request identity derived from the product and
spatial subset. Two cases using the same date/cycle but different bounding boxes
therefore no longer reuse the same regional-subset file accidentally.


## Case configuration

`case.toml` is the wrfkit-facing configuration file. Native
`namelist.wps` and `namelist.input` remain the files WPS/WRF actually read.

```toml
[namelist]
managed = true
```

With `managed=true`, TOML-owned values are overlaid onto the native files and
everything else is preserved. With `managed=false`, wrfkit never modifies the
native namelists.

Advanced users can set arbitrary upstream namelist keys under
`[advanced.wps.<group>]` and `[advanced.wrf.<group>]`. See
[case.toml configuration](case-toml.md).


## Preparation freshness guard

A successful high-level `prep` writes
`.wrfkit/work/<case>/.wrfkit-prep-manifest`. It records a stable fingerprint
of preparation-relevant TOML, hashes of both native namelists, and the pinned
WRF/WPS versions. `wrfctl run` checks that manifest before launching WRF.

This prevents a common mistake: editing the domain, forcing, physics, or native
namelist after `real.exe` has produced `wrfinput`/`wrfbdy`, then
accidentally running WRF with stale prepared inputs. If the guard fires, rerun
`wrfctl prep --case NAME`. Direct `wrfctl exec wrf` remains available as
the explicit low-level escape hatch.


## WRF-safe MPI decomposition

`wrfctl plan` reports both the available/requested MPI count and the task
count selected for `real.exe` / `wrf.exe`. The selector mirrors WRF 4.8's
automatic factorization and requires every decomposed horizontal patch to be
at least 10 grid cells in x and y.

For example, the 61 x 61 `athens-smoke` domain cannot use WRF's automatic
4 x 8 decomposition for 32 ranks because the y patch is only 7 cells. The
largest safe count at or below 32 is 30 ranks, decomposed 5 x 6.

When task count comes from `mpi_tasks=auto`, high-level `prep` and `run`
apply that safe adjustment and print it. If the user explicitly supplies an
unsafe `--ntasks`, the high-level command stops with the safe alternative
instead of silently changing an explicit request. Low-level `wrfctl exec`
remains available for direct control.
