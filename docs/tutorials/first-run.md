# Your first WRF run

This tutorial takes you from a fresh copy of wrfkit to one completed WRF
simulation.

You do **not** need to understand WRF, MPI, Slurm, or Nix before starting.
The included `athens-minimal` case is deliberately small and exists to test the
workflow.

**Goal:** finish with this message:

```text
wrf: SUCCESS COMPLETE WRF
```

!!! warning "The smoke case is not a research setup"
    A program can run successfully even when its scientific settings are not
    appropriate for a real study. Use this tutorial to learn the workflow.
    Later, use [Make a research case](../how-to/research-case.md) to design an
    experiment deliberately.

## Before you start

You need:

- a Linux x86_64 computer;
- Git;
- enough storage for WRF/WPS builds, input data, and output;
- on an HPC cluster, permission to request a compute allocation.

If you are using an HPC cluster, this tutorial uses **generic Slurm commands**.
Your site may require extra options such as an account, partition, or QoS.

UGA Sapelo2 users should also read the dedicated
[Sapelo2 guide](../single-node-guide.md), which documents Sapelo2-specific
commands and storage rules.

## Step 1 — get wrfkit

Choose a suitable working directory, then clone the repository:

```bash
git clone https://github.com/YONGHUNI/wrfkit.git
cd wrfkit
```

If you already have the repository:

```bash
cd /path/to/wrfkit
git pull
```

**Checkpoint:**

```bash
ls
```

You should see files such as `wrfctl`, `bootstrap`, `flake.nix`, and
`cases/`.

## Step 2 — if you are on an HPC cluster, get a compute node

=== "Standalone Linux"

    Stay in the repository and continue to Step 3.

=== "Slurm HPC"

    From a login node, request a single-node interactive allocation:

    ```bash
    salloc --nodes=1 --ntasks=16 --mem=64G --time=02:00:00
    srun --pty bash
    ```

    Your cluster may require additional site-specific options, for example:

    ```text
    --partition=<partition>
    --account=<account>
    --qos=<qos>
    ```

    When the shell is running on a compute node, return to the wrfkit
    repository.

    !!! important
        A login node is normally for lightweight tasks such as editing files,
        checking jobs, and submitting jobs. Building WRF/WPS and running WRF
        should happen inside a compute allocation.

    !!! note
        Some Slurm sites provide their own interactive-job helper or enter the
        compute shell differently. Use your site's documented equivalent when
        needed. UGA Sapelo2 users can follow the
        [Sapelo2 guide](../single-node-guide.md).

## Step 3 — prepare the software environment

Run:

```bash
./bootstrap
```

wrfkit detects whether it is on a normal Linux machine or a Slurm HPC system
and asks a few short questions when a machine configuration has not been saved
yet.

=== "Standalone Linux"

    Choose **Standalone Linux workstation/server** when prompted.

=== "Slurm HPC"

    Choose **Slurm HPC cluster** and then **Generic Slurm HPC**.

    Run bootstrap from the compute allocation obtained in Step 2. If wrfkit
    asks about a custom rootless-Nix store, use a writable scratch or
    project-storage path recommended by your HPC site.

    If your cluster has a dedicated wrfkit site profile, use that instead of
    the generic profile. UGA Sapelo2 users should use the Sapelo2 profile
    described in the [Sapelo2 guide](../single-node-guide.md).

If a working Nix installation is already available, bootstrap may say that no
installation is needed. That is normal.

**Checkpoint:** bootstrap should finish successfully rather than stop with an
error.

## Step 4 — check and build WRF/WPS

Check the managed environment:

```bash
./wrfctl doctor
```

The important compiler, MPI, NetCDF, WRF, and WPS checks should report
`[OK]`.

Now build WRF and WPS:

```bash
./wrfctl build all
```

The first build can take a while. Near the end of a successful build you should
see:

```text
WPS build completed.
```

!!! note
    Compiler warnings can appear during a successful build. The important
    question is whether the command reaches its completion message or stops
    with an error.

## Step 5 — look at the example before running it

The example configuration is here:

```text
cases/athens-minimal/
├── case.toml
├── namelist.wps
└── namelist.input
```

Ask wrfkit to show the resolved plan:

```bash
./wrfctl plan --case athens-minimal
```

`plan` is read-only. It shows the simulation period, forcing, domain, MPI
layout, and stages without changing the case.

If the TOML file is unfamiliar, see
[Understand case.toml](../reference/case-toml.md).

## Step 6 — prepare the model input

Run:

```bash
./wrfctl prep --case athens-minimal
```

This high-level command performs the preparation chain for the currently
supported smoke-test path:

```text
static geography
      ↓
geogrid
      ↓
GFS → ungrib
      ↓
metgrid
      ↓
real.exe
      ↓
wrfinput + wrfbdy
```

**Checkpoint:**

```bash
ls .wrfkit/work/athens-minimal/wrfinput_d01
ls .wrfkit/work/athens-minimal/wrfbdy_d01
```

Both files should exist.

## Step 7 — run WRF

Run:

```bash
./wrfctl run --case athens-minimal
```

On supported single-node Slurm systems, wrfkit manages the MPI launch. Do not
wrap this command in another multi-rank `srun`.

## Step 8 — check the result

First look for WRF output:

```bash
ls .wrfkit/work/athens-minimal/wrfout_d01_*
```

Then inspect the newest archived rank-0 log:

```bash
LOG=$(find .wrfkit/logs/athens-minimal   -maxdepth 1 -type d -name '*_wrf' | sort | tail -1)

tar -xOf "$LOG/native-logs.tar" rsl.out.0000 |
  grep "SUCCESS COMPLETE WRF"
```

Expected:

```text
wrf: SUCCESS COMPLETE WRF
```

If that line is missing, go to [Troubleshooting](../troubleshooting.md).

## What just happened?

The short user workflow was:

```text
plan → prep → run
```

Underneath, WRF still used its normal preparation programs:

```mermaid
flowchart LR
    G["Static geography"] --> GEO["geogrid"]
    F["GFS"] --> U["ungrib"]
    GEO --> M["metgrid"]
    U --> M
    M --> R["real"]
    R --> W["WRF"]
    W --> O["wrfout"]
```

wrfkit does not replace these programs. It organizes their software
environment, files, and supported execution path.

## Want to see each native stage?

For learning or debugging, you can run the lower-level steps individually:

```bash
./wrfctl fetch geog
./wrfctl exec geogrid --case athens-minimal

./wrfctl fetch gfs --case athens-minimal
./wrfctl prepare gfs --case athens-minimal
./wrfctl exec ungrib --case athens-minimal
./wrfctl exec metgrid --case athens-minimal

./wrfctl prepare wrf --case athens-minimal
./wrfctl exec real --case athens-minimal
./wrfctl exec wrf --case athens-minimal
```

For normal use, prefer the shorter `prep` + `run` path.

## Next step

To turn the smoke test into your own experiment, continue with
[Make a research case](../how-to/research-case.md). The next page explains
which scientific choices must be reconsidered instead of copied blindly.
