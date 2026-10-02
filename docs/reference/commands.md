# wrfctl command reference

Commands below are run from the repository root unless noted otherwise.

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
