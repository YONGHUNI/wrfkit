# Features

wrfkit helps you run the Weather Research and Forecasting (**WRF**) model
without hiding how WRF and its preprocessing system (**WPS**) work.

The main idea is simple:

> **Hide the system complexity, not the scientific configuration.**

wrfkit handles software setup, repeatable workflow steps, and single-node
cluster execution. You still choose the scientific settings of your experiment.

If a term on this page is unfamiliar, use the
[plain-language glossary](reference/glossary.md).

## At a glance

| Feature | What it means in plain language | Current status |
| --- | --- | --- |
| Reproducible software environment | Use a controlled set of compilers, MPI, NetCDF, WRF, and WPS instead of whatever happens to be installed on a machine | **Validated** |
| Transparent case configuration | Keep a short TOML description while the real WRF/WPS namelists remain visible | **Validated** |
| Plan → Prep → Run workflow | See the plan first, prepare all model inputs, then run WRF | **Validated on Sapelo2; plan/prep also on Lambda** |
| Slurm-aware MPI execution | Use CPUs assigned by a Slurm cluster without manually rebuilding the launch command | **Validated on Sapelo2** |
| WRF-safe MPI decomposition | Reduce an automatic rank count when WRF's grid would otherwise be split into patches that are too small | **Validated on Sapelo2** |
| Reusable input data | Store geography and weather-input files once and reuse them across cases or repository clones | **Validated on Sapelo2** |
| Preparation freshness guard | Stop a high-level run when its prepared inputs no longer match the case; allow deliberate reuse only with an explicit flag | **CI validated; stale detection validated on Sapelo2** |
| Run checks and logs | Check for WRF's success message, a new output file, and archive native logs for each run | **Validated on Sapelo2** |

The exact test boundary is recorded in the
[validation matrix](validation.md).

Here, **validated** means the path has actually been run and produced the
expected program-level result. **Validated on Sapelo2** means that specific
behavior was exercised on UGA's Slurm cluster. It does not mean every HPC
system will behave the same way.

## Where WPS fits

A real-data WRF run does not start directly from a weather file. WPS first
prepares the geography and weather data for the model grid.

~~~mermaid
flowchart LR
    G["Static geography<br/>terrain, land use, soil"]
    F["Weather input<br/>for example GFS"]
    GG["geogrid"]
    U["ungrib"]
    M["metgrid"]
    R["real.exe"]
    W["wrf.exe"]
    O["wrfout"]

    G --> GG
    F --> U
    GG --> M
    U --> M
    M --> R --> W --> O
~~~

wrfkit does **not** replace these programs. It organizes and checks the steps
around them.

## Repeatable software environments

### The problem

WRF depends on several pieces of software: a compiler, MPI, NetCDF, WRF itself,
WPS, and more. If two computers provide different versions, the same source code
can behave differently or fail to build.

### What wrfkit does

wrfkit uses Nix to provide a controlled software environment. On systems where
you do not have administrator access, such as many HPC clusters, it can use
rootless Nix.

~~~text
your machine
    ↓
wrfkit environment
    ├── compiler
    ├── MPI
    ├── NetCDF
    ├── WRF
    └── WPS
~~~

You do not need to run raw WRF binaries from the host environment.
<code>wrfctl</code> enters the managed environment for you.

**Status:** validated on ordinary Linux and the current Sapelo2 workflow for the
supported WRF/WPS versions.

[Learn how the environment works](explanation/how-it-works.md#why-nix)

## Scientific settings stay visible

### The problem

A wrapper can make a model easier to run, but it becomes dangerous if it also
hides important scientific choices.

### What wrfkit does

Each case keeps three main files:

~~~text
cases/my-case/
├── case.toml
├── namelist.wps
└── namelist.input
~~~

<code>case.toml</code> gives wrfkit a compact description of common settings
and input data. The native <code>namelist.wps</code> and
<code>namelist.input</code> files remain visible and are still the files WPS
and WRF read.

A useful way to remember the split is:

~~~text
case.toml   → what experiment you intend to run
namelist.*  → what WRF/WPS actually receive
wrfctl      → how the computer executes the workflow
~~~

Advanced users can still set native WRF/WPS options that are not represented by
a short convenience field.

**Status:** TOML rendering and native namelist preservation are validated.

[Read the case.toml reference](reference/case-toml.md)

## Plan → Prep → Run

The normal high-level workflow is deliberately short:

~~~bash
./wrfctl plan --case my-case
./wrfctl prep --case my-case
./wrfctl run  --case my-case
~~~

### plan: look before changing anything

<code>plan</code> is read-only. It shows the resolved simulation period,
domain, forcing, MPI layout, cached inputs, and the stages that would run.

### prep: make the case ready for WRF

<code>prep</code> carries the case through the preprocessing chain and
<code>real.exe</code>. Its final job is to create WRF's initial and boundary
files:

~~~text
wrfinput_d0*
wrfbdy_d01
~~~

### run: launch WRF and check the result

<code>run</code> launches <code>wrf.exe</code>, requires the current run to
report <code>SUCCESS COMPLETE WRF</code>, and checks that a new
<code>wrfout_d01_*</code> was created.

The individual WPS/WRF programs are still available through lower-level
commands for debugging and teaching.

**Status:** the high-level workflow has been validated on Lambda Vector and
Sapelo2 for the earlier validation cases. The current 3 km
<code>athens-highres</code> case is validated end to end on Sapelo2; its 3 km
Lambda Vector end-to-end regression remains pending because the observed
automatic 128-rank launch exceeded the available PRRTE slots.

[Follow the first-run tutorial](tutorials/first-run.md)

## Slurm-aware MPI without hiding MPI

A cluster such as Sapelo2 uses **Slurm** to assign CPUs to jobs. WRF then uses
**MPI ranks** to divide the calculation among those CPUs.

wrfkit keeps that relationship visible.

For example, the bundled 61 × 61 minimal validation grid was given 32 CPUs on Sapelo2:

~~~text
Slurm allocation
└── 32 CPUs

WPS
└── 32 MPI ranks

real / WRF
└── 30 MPI ranks
    └── 5 × 6 grid decomposition
~~~

Why 30 instead of 32? WRF would split this small grid into patches that are too
small if it used its automatic 4 × 8 layout for 32 ranks. wrfkit detects that
before launching the high-level WRF stages and selects the largest safe count
at or below the automatic request.

It reports the adjustment instead of silently hiding it:

~~~text
[WARN] WRF tasks auto-adjusted 32 -> 30 ...
~~~

If you explicitly request an unsafe <code>--ntasks</code> value, the high-level
command stops rather than silently changing your explicit choice.

**Status:** validated for single-node Slurm execution on UGA Sapelo2.
Multi-node MPI is **not** yet claimed as validated.

[See the single-node guide](single-node-guide.md)

## Reuse large input data

Some files are useful to many experiments and do not need to be copied into
every repository.

The clearest examples are:

- **static geography** used by WPS, such as terrain and land-use source data;
- **raw weather forcing**, currently GFS in the automatic workflow.

By default they live under:

~~~text
<repository>/.wrfkit/data/
~~~

You can instead point wrfkit at a reusable data root:

~~~ini
data_root=/path/to/shared/wrfkit-data
~~~

Then the layout can look like this:

~~~text
shared wrfkit-data/
├── geog/
└── gfs/
      │
      ├──────────────┐
      ↓              ↓
case A workspace   case B workspace
~~~

The word **shared** does not have to mean “shared with another person.” It can
mean shared by several cases, several repository clones, or several Slurm jobs
owned by the same researcher.

Case-specific products stay in each repository workspace:

~~~text
geo_em.*
FILE:*
met_em.*
wrfinput*
wrfbdy*
wrfout*
~~~

That is intentionally conservative. Some intermediate files *can* be reused
when two experiments are exactly compatible, but wrfkit does not currently
guess that they are interchangeable.

**Status:** an external <code>data_root</code> using both geography and cached
GFS was validated through <code>geogrid → ungrib → metgrid → real</code> on
Sapelo2.

[See where files are stored](reference/files-and-folders.md#reuse-downloaded-data-across-projects)

## Guard against stale prepared inputs

A case can change after <code>real.exe</code> has already created
<code>wrfinput</code> and <code>wrfbdy</code>. Running WRF with those older
prepared inputs while the tracked namelists describe something else is easy to
do accidentally.

wrfkit records a preparation manifest and compares it with the current case at
high-level <code>run</code> time. If <code>case.toml</code>,
<code>namelist.wps</code>, or <code>namelist.input</code> changed, the default
behavior is now to stop before <code>wrf.exe</code> launches:

~~~text
[WARN] Configuration changed since the last prep.
  Changed since prep:
    - namelist.input
[ERROR] Prepared inputs are stale; refusing to launch wrf.exe.
~~~

The normal fix is:

~~~bash
./wrfctl prep --case my-case
./wrfctl run  --case my-case
~~~

If reusing the older <code>wrfinput</code>/<code>wrfbdy</code> is deliberate,
make that decision explicit:

~~~bash
./wrfctl run --case my-case --allow-stale-prep
~~~

A missing prep manifest or a pinned WRF/WPS version mismatch remains a hard
error and is not bypassed by the flag.

**Status:** stale-case detection was exercised live on Sapelo2 under the earlier
warn-and-continue policy. The current hard-stop and explicit-override behavior
is covered by CI; a post-change live cluster regression remains pending.

## Check success and keep useful logs

A process returning to the shell is not enough evidence that a WRF run
succeeded.

The high-level run checks for:

~~~text
SUCCESS COMPLETE WRF
+ a new wrfout_d01_* file
~~~

Native WPS/WRF logs are also archived by run under:

~~~text
.wrfkit/logs/<case>/<run-id>/
~~~

This gives you a record of what happened without moving the scientific output
out of the normal case workspace.

**Status:** per-run log archiving and high-level success checks are validated.

[Learn how to check a run](how-to/check-run.md)

## What is not ready yet?

wrfkit intentionally labels unfinished areas instead of presenting them as
supported features.

Current important boundaries include:

- **3 km Lambda Vector regression:** the current case resolves correctly, but
  the observed 128-rank standalone automatic launch exceeded PRRTE's available
  slots; use a compatible explicit rank count or adjust the auto-task policy
  before claiming the 3 km Lambda path as validated;
- **multi-node MPI:** not validated;
- **restart/recovery workflow:** not validated;
- **WRF-Chem / WRFDA:** not currently claimed as supported.

Use the [validation matrix](validation.md) whenever you need the exact,
up-to-date support boundary.
