# High-level and low-level workflows

wrfkit exposes the same WPS/WRF pipeline at two levels.

**High-level commands** express user intent:

```bash
wrfctl prep --case my-case
wrfctl run  --case my-case
```

**Low-level commands** expose individual acquisition, staging, and native model
programs:

```bash
wrfctl fetch ...
wrfctl prepare ...
wrfctl exec ...
```

Use the high-level path for normal research runs. Use the low-level path when
you are teaching, diagnosing one stage, testing an input, or deliberately
rerunning only part of the pipeline.

This page assumes an interactive
[wrfkit shell](../tutorials/bootstrap-and-shell.md). Outside that shell, prefix
commands with `./`.

## What `prep` expands to

The current `prep` implementation performs these stages:

| High-level stage | Low-level command |
| --- | --- |
| render/validate managed case values | `wrfctl config --case NAME` |
| ensure static geography | `wrfctl fetch geog --case NAME` for a managed geography profile |
| run geogrid | `wrfctl exec geogrid --case NAME` |
| ensure GFS forcing | `wrfctl fetch gfs --case NAME` |
| stage forcing/Vtable/GRIB links | `wrfctl prepare gfs --case NAME` |
| decode GRIB | `wrfctl exec ungrib --case NAME` |
| interpolate forcing to the WRF grid | `wrfctl exec metgrid --case NAME` |
| stage WRF runtime files | `wrfctl prepare wrf --case NAME` |
| create initial/boundary files | `wrfctl exec real --case NAME` |

After `real.exe`, high-level `prep` verifies the expected
`wrfinput_d0*` and `wrfbdy_d01` files and writes a preparation manifest.

A manual equivalent for the current GFS path is:

```bash
CASE=my-case

wrfctl config --case "$CASE"

wrfctl fetch geog --case "$CASE"
wrfctl exec geogrid --case "$CASE"

wrfctl fetch gfs --case "$CASE"
wrfctl prepare gfs --case "$CASE"
wrfctl exec ungrib --case "$CASE"
wrfctl exec metgrid --case "$CASE"

wrfctl prepare wrf --case "$CASE"
wrfctl exec real --case "$CASE"
```

!!! important "Manual real.exe is not the same contract as high-level prep"
    The individual commands do not reproduce every orchestration guarantee of
    `wrfctl prep`. In particular, high-level prep owns the final verification
    and preparation manifest.

    If you manually rerun stages for debugging and then want to return to the
    guarded high-level workflow, run `wrfctl prep --case NAME` again before
    `wrfctl run`.

## What `run` adds around `wrf.exe`

The native model command is:

```bash
wrfctl exec wrf --case my-case
```

The high-level command is:

```bash
wrfctl run --case my-case
```

These are **not equivalent safety contracts**.

High-level `run` additionally:

- renders current TOML-managed namelist values;
- checks the preparation manifest;
- refuses stale prepared inputs by default;
- selects a WRF-safe MPI decomposition for the domain;
- removes fixed-name stale RSL files before launch;
- requires a current `rsl.out.0000`;
- requires `SUCCESS COMPLETE WRF` in the current run;
- requires a newly created `wrfout_d01_*`.

Low-level `exec wrf` is intentionally more direct. It still uses wrfkit's
environment, launcher backend, case workspace, and log archiving, but it does
not promise the complete high-level freshness/output contract.

## Why `exec` exists

`wrfctl exec` gives you a controlled way to call native binaries while
keeping the pinned environment and launcher logic.

Examples:

```bash
wrfctl exec geogrid --case my-case
wrfctl exec metgrid --case my-case --ntasks 16
wrfctl exec real    --case my-case
wrfctl exec wrf     --case my-case
```

WRF-side MPI-capable commands currently include `wrf`, `real`, `ndown`,
and `tc`. WPS MPI-capable commands include `geogrid` and `metgrid`.
`ungrib` is launched through the pinned environment without MPI.

The command also accepts other programs:

```bash
wrfctl exec python -- --version
wrfctl exec ldd .wrfkit/install/wrf-4.8.0/bin/wrf
```

Use `--` when program arguments could be confused with wrfctl options.

## The case workspace

With `--case NAME`, exec stages the runtime links and changes into:

```text
.wrfkit/work/NAME/
```

The tracked scientific files remain in:

```text
cases/NAME/
├── case.toml
├── namelist.wps
└── namelist.input
```

The workspace receives links/runtime files plus generated WPS/WRF products.
This separation is described in
[How wrfkit works](../explanation/how-it-works.md) and
[Files and folders](../reference/files-and-folders.md).

## MPI overrides

For a one-off stage:

```bash
wrfctl exec metgrid --case my-case --ntasks 16
wrfctl exec wrf --case my-case --ntasks 24
wrfctl exec wrf --case my-case --launcher mpirun
```

High-level `prep` and `run` add domain-aware rank safety. An explicit unsafe
high-level `--ntasks` request is rejected instead of silently changed.
Low-level exec gives you more direct control, so use it with more care.

See [wrfctl command reference](../reference/commands.md) for launcher details.

## A debugging pattern

When high-level prep fails, do not immediately rerun everything blindly.
Identify the failed stage, inspect its logs, then reproduce that stage directly.

For example, after a metgrid failure:

```bash
wrfctl exec metgrid --case my-case
```

If the issue is corrected and you want to return to the protected workflow:

```bash
wrfctl prep --case my-case
wrfctl run  --case my-case
```

For log locations and common failures, see
[Troubleshooting](../troubleshooting.md).

## Related pages

- Environment first: [Bootstrap and enter the wrfkit shell](../tutorials/bootstrap-and-shell.md)
- Configure science: [Understand case.toml](../reference/case-toml.md)
- Design a new experiment: [Make a research case](research-case.md)
- Full command syntax: [wrfctl command reference](../reference/commands.md)
- Architecture: [How wrfkit works](../explanation/how-it-works.md)
