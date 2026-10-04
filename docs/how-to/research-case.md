# Make a research case

A **case** is the tracked scientific configuration for one WRF experiment.

The included `athens-minimal` case is useful for learning the file layout and
testing the workflow. It is **not** a scientific recommendation.

## 1. Copy the example

```bash
cp -a cases/athens-minimal cases/my-case
```

You now have:

```text
cases/my-case/
├── README.md
├── case.toml
├── namelist.input
└── namelist.wps
```

These are the files you intentionally edit and commit.

Generated WRF/WPS products live elsewhere, under:

```text
.wrfkit/work/my-case/
```

## 2. Change the scientific design, not just the date

At minimum, review these choices:

| Question | Examples of relevant settings |
| --- | --- |
| Where and how large is the model domain? | projection, center, `e_we`, `e_sn`, `dx`, `dy` |
| How long does the simulation run? | start, end, spin-up |
| What drives the model at its boundaries? | forcing dataset, cycle, interval |
| How is the atmosphere represented? | vertical levels, physics, time step |
| What output do you need? | history interval, variables, file frequency |
| Is the static geography suitable? | WPS geography data and resolution |

!!! danger "Changing only the date is not enough"
    `SUCCESS COMPLETE WRF` means the program finished. It does not mean the
    experiment is scientifically appropriate.

## 3. Use `case.toml` for common controls

Most common wrfkit-facing settings are in:

```text
cases/my-case/case.toml
```

For example:

```toml
[time]
start = 2026-10-01T00:00:00Z
end   = 2026-10-02T00:00:00Z

[domain]
e_we = [151]
e_sn = [151]
dx = 9000
dy = 9000

[model]
time_step = 45

[output]
history_interval_minutes = 60
```

The [case.toml guide](../reference/case-toml.md) explains each section and the
current convenience fields.

## 4. Use advanced TOML when you need lower-level control

You do not have to wait for wrfkit to add a convenience field for every WRF
option.

For example:

```toml
[advanced.wrf.physics]
mp_physics = [8]
cu_physics = [1]
ra_lw_physics = [4]
ra_sw_physics = [4]

[advanced.wrf.dynamics]
hybrid_opt = 2
diff_opt = [2]
km_opt = [4]
```

These tables map directly to the corresponding native WRF namelist groups.

The native `namelist.wps` and `namelist.input` remain visible so you can
always inspect exactly what WPS and WRF receive.

## 5. Check before preparing data

Validate the TOML/native mapping without writing files:

```bash
./wrfctl config --case my-case --check
```

Then inspect the resolved experiment:

```bash
./wrfctl plan --case my-case
```

Read the output carefully. Check the simulation period, forcing, domain,
timestep, physics suite, and planned stages.

## 6. Prepare and run

For the currently supported automatic low-resolution geography + GFS path:

```bash
./wrfctl prep --case my-case
./wrfctl run  --case my-case
```

`prep` includes `real.exe` and should create:

```text
wrfinput_d0*
wrfbdy_d01
```

`run` then executes `wrf.exe` and checks for current successful output.

When you need to inspect or rerun one native stage, the lower-level
`fetch`, `prepare`, and `exec` commands remain available.

## 7. Run a short test before a long experiment

Before committing many hours of compute time, use a representative short run
and record:

- whether `real` and WRF complete;
- wall time;
- memory use;
- output volume;
- expected variables and timestamps;
- whether fields look physically reasonable.

Only then scale the experiment.

## What wrfkit does not choose for you

wrfkit does not decide which resolution, microphysics scheme, PBL scheme,
cumulus treatment, radiation scheme, spin-up period, or validation method is
best for your research question.

Those are scientific decisions and should remain visible and reviewable.
