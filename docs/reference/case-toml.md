# Understand `case.toml`

A **case** is one WRF experiment. wrfkit keeps the scientific configuration in:

```text
cases/<case-name>/
├── case.toml
├── namelist.wps
└── namelist.input
```

Think of the three files this way:

| File | Purpose |
| --- | --- |
| `case.toml` | common scientific settings + wrfkit workflow settings |
| `namelist.wps` | full native WPS configuration |
| `namelist.input` | full native WRF configuration |

For most work, start with `case.toml`. The native namelists remain visible and
are still the files that WPS and WRF actually read.

!!! important "What wrfkit does not decide"
    wrfkit can check syntax and some relationships between fields. It cannot
    decide whether a domain, physics scheme, time step, or other scientific
    choice is appropriate for your study.

## The short version

A beginner usually needs to understand these sections first:

```toml
[time]            # when the simulation runs
[forcing]         # which weather data drives the model
[forcing.subset]  # which part of that weather data to download
[geography]       # static WPS geography
[domain]          # where the WRF grid is and how large/fine it is
[model]           # numerical integration settings
[physics]         # physics preset
[output]          # how often WRF writes output
```

When those are not enough, use `[advanced.wrf.*]` or `[advanced.wps.*]`
to write lower-level native namelist options directly.

## A minimal example

The bundled Athens smoke test looks like this:

```toml
schema_version = 1

[case]
description = "Athens, Georgia single-domain smoke test"

[namelist]
managed = true

[time]
start = 2026-09-30T00:00:00Z
end   = 2026-09-30T06:00:00Z
forcing_interval_seconds = 10800

[forcing]
provider = "gfs"
product = "0p25"
cycle = 2026-09-30T00:00:00Z
forecast_hours = [0, 3, 6]

[forcing.subset]
west = 265
east = 288
south = 25
north = 42

[geography]
dataset = "wps-lowres-mandatory"
resolution = "lowres"

[domain]
max_dom = 1
parent_id = [1]
parent_grid_ratio = [1]
i_parent_start = [1]
j_parent_start = [1]
e_we = [61]
e_sn = [61]
e_vert = [45]
dx = 12000
dy = 12000
map_proj = "lambert"
ref_lat = 33.95
ref_lon = -83.38
truelat1 = 30.0
truelat2 = 60.0
stand_lon = -84.0

[model]
time_step = 72

[physics]
suite = "CONUS"

[output]
history_interval_minutes = 180
frames_per_outfile = 1
restart = false
```

Before changing anything, remember two useful read-only checks:

```bash
./wrfctl config --case my-case --check
./wrfctl plan --case my-case
```

The first checks the configuration. The second shows the resolved experiment
that wrfkit intends to run.

## TOML in 60 seconds

A normal value:

```toml
time_step = 72
```

A section:

```toml
[model]
time_step = 72
```

An array:

```toml
e_we = [101]
```

A Boolean:

```toml
restart = false
```

For nested WRF domains, several settings use arrays with one value per domain.

## Settings you will use most often

### Experiment identity and namelist control

| Field | Meaning |
| --- | --- |
| `schema_version` | wrfkit TOML format version; keep `1` for the current format |
| `case.description` | free-text description for humans and provenance |
| `namelist.managed` | whether wrfkit may update TOML-owned native namelist fields |

With:

```toml
[namelist]
managed = true
```

wrfkit updates only the fields represented by TOML and preserves other native
namelist settings.

With `managed = false`, wrfkit does not modify `namelist.wps` or
`namelist.input`. TOML can still control wrfkit-specific workflow settings,
such as forcing acquisition.

### Time

```toml
[time]
start = 2026-09-30T00:00:00Z
end   = 2026-09-30T06:00:00Z
forcing_interval_seconds = 10800
```

| Field | Meaning |
| --- | --- |
| `start` | simulation start time |
| `end` | simulation end time |
| `forcing_interval_seconds` | spacing between external meteorological input times |

Times must include a UTC offset. A trailing `Z` means UTC.

`10800` seconds is 3 hours. A six-hour simulation using three-hour forcing
therefore needs forcing at 0, 3, and 6 hours.

### Weather forcing

```toml
[forcing]
provider = "gfs"
product = "0p25"
cycle = 2026-09-30T00:00:00Z
forecast_hours = [0, 3, 6]
```

| Field | Meaning | Current automatic support |
| --- | --- | --- |
| `provider` | weather-data provider | `"gfs"` |
| `product` | provider product | `"0p25"` |
| `cycle` | forecast initialization time | GFS 00/06/12/18 UTC cycle |
| `forecast_hours` | lead times to acquire | non-negative hour values |

The forecast hours must cover every WPS input time required by the simulation.

### Forcing download area

```toml
[forcing.subset]
west = 265
east = 288
south = 25
north = 42
```

| Field | Meaning |
| --- | --- |
| `west` | western longitude |
| `east` | eastern longitude |
| `south` | southern latitude |
| `north` | northern latitude |

The current GFS downloader uses longitudes from **0 to 360° east**.
For example, 275°E is the same longitude as 85°W.

The subset must be large enough to cover the WRF domain and the surrounding
area needed for boundary input.

### Static geography

For the built-in smoke test:

```toml
[geography]
dataset = "wps-lowres-mandatory"
resolution = "lowres"
```

The two fields have different jobs:

| Field | Meaning |
| --- | --- |
| `dataset` | where the WPS static geography comes from |
| `resolution` | native WPS `geog_data_res` selector |

For ordinary research cases, wrfkit recognizes the official high-resolution
mandatory-data profile:

```toml
[geography]
dataset = "wps-highres-mandatory"
resolution = "default"
```

The high-resolution downloader is still a follow-up milestone, but
`resolution` is no longer forced to `"default"`. A researcher may keep WPS's
native selector freedom, for example:

```toml
resolution = "30s+default"
```

The small smoke-test package is different: because it only contains the
low-resolution teaching/test data expected by wrfkit, its selector remains
restricted to `"lowres"`.

#### Use geography you already have

If a lab or HPC system already provides WPS geography, use the external profile:

```toml
[geography]
dataset = "external"
path = "/work/my-lab/shared/WPS_GEOG"
resolution = "default"
```

wrfkit does not download, copy, or modify an external geography directory. It
checks that the directory exists during `prep` and links the case workspace's
`geog` path to it.

An absolute `path` may point to another filesystem, which is useful on HPC
systems. A relative path is resolved under the machine's reusable data root:

```toml
[geography]
dataset = "external"
path = "my-custom-geog"
resolution = "30s+default"
```

With:

```ini
data_root=/work/$USER/wrfkit-data
```

that resolves to:

```text
/work/$USER/wrfkit-data/geog/my-custom-geog
```

This keeps the scientific choice (`resolution`) in the case while allowing the
physical storage location to follow the machine.

Use `./wrfctl plan --case NAME` to see the resolved dataset, selector,
management mode, and path before running anything.


### Domain

The `[domain]` section answers three basic questions:

1. How many WRF domains are there?
2. Where are they?
3. How large and how fine are their grids?

#### Grid size and spacing

```toml
[domain]
max_dom = 1
e_we = [61]
e_sn = [61]
e_vert = [45]
dx = 12000
dy = 12000
```

| Field | Meaning |
| --- | --- |
| `max_dom` | number of WRF domains |
| `e_we` | west-east staggered grid dimension |
| `e_sn` | south-north staggered grid dimension |
| `e_vert` | number of full vertical levels |
| `dx` | horizontal grid spacing in the x direction |
| `dy` | horizontal grid spacing in the y direction |

For projected grids, `dx` and `dy` are in meters. Thus `12000` means
12 km.

A smaller grid spacing gives finer spatial resolution, but usually increases
the computational cost substantially.

#### Projection and location

```toml
map_proj = "lambert"
ref_lat = 33.95
ref_lon = -83.38
truelat1 = 30.0
truelat2 = 60.0
stand_lon = -84.0
```

| Field | Meaning |
| --- | --- |
| `map_proj` | WPS map projection |
| `ref_lat` | reference latitude |
| `ref_lon` | reference longitude |
| `truelat1` | first true latitude |
| `truelat2` | second true latitude when used |
| `stand_lon` | standard longitude / central meridian |

The current parser also accepts `pole_lat` and `pole_lon` when needed.

#### Nesting

For nested domains:

```toml
parent_id = [1]
parent_grid_ratio = [1]
i_parent_start = [1]
j_parent_start = [1]
```

| Field | Meaning |
| --- | --- |
| `parent_id` | parent domain for each grid |
| `parent_grid_ratio` | how much finer a nest is than its parent |
| `i_parent_start` | nest start in the parent's west-east direction |
| `j_parent_start` | nest start in the parent's south-north direction |

For a single-domain case, these remain the simple d01 values shown above.

??? note "Other domain fields"
    The convenience layer also accepts lower-level domain fields such as:

    ```toml
    [domain]
    parent_time_step_ratio = [1]
    feedback = 1
    smooth_option = 0
    p_top_requested = 5000
    ```

    These map to WRF domain settings. Use the upstream WRF documentation when
    choosing scientific values.

### Model time step

```toml
[model]
time_step = 72
```

This is WRF's integration time step in seconds.

The annotated template records the common WRF real-data rule of thumb of no
more than about `6 × dx(km)`. For a 12 km grid, 72 s is therefore an upper
rule-of-thumb value, not a guarantee of numerical stability.

If WRF reports CFL-related instability, a smaller time step may be needed.

### Physics suite

```toml
[physics]
suite = "CONUS"
```

This maps to WRF's `physics_suite`.

A physics suite is a coordinated preset. It is not automatically the best
choice for every region, resolution, season, or research question.

If you need to choose individual schemes, use the advanced WRF interface below.

### Output

```toml
[output]
history_interval_minutes = 180
frames_per_outfile = 1
restart = false
```

| Field | Meaning |
| --- | --- |
| `history_interval_minutes` | how often WRF writes history output |
| `frames_per_outfile` | number of output times stored in each history file |
| `restart` | native WRF restart switch |
| `restart_interval_minutes` | restart-output interval when configured |

Smaller history intervals create more frequent output and normally require more
storage.

!!! warning
    The TOML restart fields can map into the native namelist, but wrfkit's
    complete restart/recovery workflow is not currently claimed as validated.

## Lower-level control

The convenience fields above are intentionally limited. wrfkit does not try to
re-create every WRF/WPS namelist option as a custom TOML field.

Instead, advanced sections map directly to native namelist groups:

```text
[advanced.wrf.physics]   →  &physics in namelist.input
[advanced.wrf.dynamics]  →  &dynamics in namelist.input
[advanced.wps.geogrid]   →  &geogrid in namelist.wps
```

### WRF example

```toml
[advanced.wrf.physics]
mp_physics = [8]
cu_physics = [1]
ra_lw_physics = [4]
ra_sw_physics = [4]
radt = [12]
```

### WPS example

```toml
[advanced.wps.geogrid]
geog_data_res = ["default"]
opt_geogrid_tbl_path = "."
```

If a convenience field and an advanced field write the same native key, the
**advanced value wins**.

??? example "More advanced WRF examples"

    ```toml
    [advanced.wrf.domains]
    p_top_requested = 5000
    parent_time_step_ratio = [1]
    feedback = 1
    smooth_option = 0

    [advanced.wrf.dynamics]
    hybrid_opt = 2
    diff_opt = [2]
    km_opt = [4]

    [advanced.wrf.bdy_control]
    spec_bdy_width = 5
    specified = [true]
    ```

??? example "More advanced WPS examples"

    ```toml
    [advanced.wps.share]
    wrf_core = "ARW"
    active_grid = [true]

    [advanced.wps.ungrib]
    out_format = "WPS"
    prefix = "FILE"

    [advanced.wps.metgrid]
    fg_name = ["FILE"]
    opt_metgrid_tbl_path = "."
    ```

### Native options not known to wrfkit

Advanced sections intentionally accept native group/key names that are not
hard-coded into wrfkit:

```toml
[advanced.wrf.some_native_group]
some_native_key = 123
```

That makes the interface extensible, but it also means **you** are responsible
for using a valid WRF/WPS group, key, type, and scientific value.

### Raw escape hatch

Some Fortran namelist syntax cannot be expressed cleanly as ordinary TOML
values. In that case:

```toml
[advanced.wrf_raw.domains]
"eta_levels(1:3)" = "1.0, 0.5, 0.0"
```

The right-hand string is inserted verbatim as the native namelist value.

Use `*_raw` only when ordinary TOML values are not enough.

## How TOML values become Fortran values

| TOML value | Native namelist form |
| --- | --- |
| `"text"` | quoted string |
| `12` | integer |
| `12.5` | floating-point number |
| `true` / `false` | `.true.` / `.false.` |
| `[1, 2, 3]` | comma-separated values |

## A safe editing routine

Use the same sequence whenever you change a research case:

```bash
# 1. edit
$EDITOR cases/my-case/case.toml

# 2. validate without writing native namelists
./wrfctl config --case my-case --check

# 3. inspect the resolved experiment
./wrfctl plan --case my-case

# 4. prepare inputs
./wrfctl prep --case my-case

# 5. run WRF
./wrfctl run --case my-case
```

If the scientific configuration changes after preparation, run `prep` again
when the change requires new `wrfinput` or `wrfbdy` files.

## Complete annotated template

The repository also contains a copyable template:

```text
config/case.template.toml
```

It includes additional advanced examples and comments.

For native WRF/WPS options beyond wrfkit's convenience layer, use the official
WRF documentation together with the `[advanced.*]` interface.
