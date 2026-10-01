# Your first WRF run

This tutorial gets one tiny WRF simulation to finish successfully. You do not
need prior WRF or HPC experience.

**Goal:** see this line at the end:

```text
wrf: SUCCESS COMPLETE WRF
```

The tutorial uses the included `athens-smoke` case. It is a **software test**,
not a research-quality weather experiment.

## Before you start

You need:

- a Linux x86_64 machine;
- Git;
- enough disk space for WRF/WPS, input data, and outputs;
- on Sapelo2, your normal SSH/login access.

!!! note "If you are on Sapelo2"
    It is normal to type `sbatch` or `interact` on a login node. The heavy
    computation itself must run on a compute node.

## Step 1 — get the code

On Sapelo2, start from your login shell:

```bash
cd ~/work/project
git clone git@github.com:YONGHUNI/wrfkit.git
cd wrfkit
```

If you already cloned the repository:

```bash
cd ~/work/project/wrfkit
git pull
```

**Checkpoint:** this should show files such as `wrfctl`, `bootstrap`,
`flake.nix`, and `cases/`:

```bash
ls
```

## Step 2 — move to a compute node on Sapelo2

Skip this step on a normal Linux workstation/server.

```bash
interact -c 16 --mem=64G --time=02:00:00 --gres=lscratch:100
```

Check where you are:

```bash
hostname
```

The hostname should now be a compute node, not `ss-sub*`.

!!! warning "Do not build WRF on a Sapelo2 login node"
    If wrfkit detects an `ss-sub*` login node during bootstrap, it stops on
    purpose.

## Step 3 — prepare Nix

On Sapelo2:

```bash
cd ~/work/project/wrfkit
./bootstrap --profile sapelo2
```

On another Linux machine without Nix:

```bash
./bootstrap
```

If you see:

```text
wrfkit: a working nix installation is already available; bootstrap is not needed.
```

that is **not an error**. It means the environment is already available.

## Step 4 — check and build the software

```bash
./wrfctl doctor
./wrfctl build all
```

The first build can take time. wrfkit pins the compiler, MPI, NetCDF, WRF, and
WPS environment so later runs use the same software stack.

**Checkpoint:** after the build, the installed programs are under:

```text
.wrfkit/install/
├── wrf-4.8.0/bin/
└── wps-4.7.0/bin/
```

## Step 5 — prepare the map

Download the small geography dataset used by the smoke test:

```bash
./wrfctl fetch geog
```

Run `geogrid`:

```bash
./wrfctl exec geogrid --case athens-smoke
```

**Checkpoint:**

```bash
ls .wrfkit/work/athens-smoke/geo_em.d01.nc
```

If that file exists, the map/domain stage worked.

## Step 6 — prepare weather input

Download the GFS files defined by the smoke case:

```bash
./wrfctl fetch gfs --case athens-smoke
```

Stage them in WPS format:

```bash
./wrfctl prepare gfs --case athens-smoke
```

Convert the GRIB weather files:

```bash
./wrfctl exec ungrib --case athens-smoke
```

Put the weather fields onto the WRF grid:

```bash
./wrfctl exec metgrid --case athens-smoke
```

**Checkpoint:**

```bash
ls .wrfkit/work/athens-smoke/met_em.*
```

You should see `met_em` files for the smoke-test times.

!!! note "Why are there several commands?"
    WPS is a preparation pipeline. `geogrid` makes the map, `ungrib`
    decodes the external weather data, and `metgrid` places those fields on
    the model grid.

## Step 7 — create WRF initial and boundary files

```bash
./wrfctl prepare wrf --case athens-smoke
./wrfctl exec real --case athens-smoke
```

**Checkpoint:**

```bash
ls .wrfkit/work/athens-smoke/wrfinput_d01
ls .wrfkit/work/athens-smoke/wrfbdy_d01
```

## Step 8 — run WRF

```bash
./wrfctl exec wrf --case athens-smoke
```

Inside a Slurm allocation, wrfkit chooses the single-node MPI launch path for
you. Do **not** add another `srun -n ...` around this command.

## Step 9 — check success

Find the newest WRF log archive:

```bash
LOG=$(find .wrfkit/logs/athens-smoke \
  -maxdepth 1 -type d -name '*_wrf' | sort | tail -1)
```

Check rank 0:

```bash
tar -xOf "$LOG/native-logs.tar" rsl.out.0000 |
  grep "SUCCESS COMPLETE WRF"
```

Expected:

```text
wrf: SUCCESS COMPLETE WRF
```

Then look for model output:

```bash
ls .wrfkit/work/athens-smoke/wrfout_d01_*
```

## You just used the full pipeline

```text
geogrid
   -> GFS download
   -> ungrib
   -> metgrid
   -> real
   -> wrf
   -> wrfout
```

Next, read [Make a research case](../how-to/research-case.md). It explains why
the smoke test should not simply be copied and treated as a scientific setup.
