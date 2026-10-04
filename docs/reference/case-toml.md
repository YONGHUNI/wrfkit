# Understand `case.toml`

A **case** is one WRF experiment. Its tracked files live under:

```text
cases/<case-name>/
├── case.toml
├── namelist.wps
└── namelist.input
```

`case.toml` is the short, human-readable configuration that wrfkit understands.
The two native namelist files still remain the files that WPS and WRF actually
read.

The simplest way to think about the three files is:

```text
case.toml       → common settings + wrfkit workflow settings
namelist.wps    → full native WPS configuration
namelist.input  → full native WRF configuration
```

You can stay with the easy TOML fields for common work, then use
`[advanced.*]` tables when you need lower-level WRF/WPS control.

!!! important "TOML does not make a setting scientifically correct"
    wrfkit checks syntax and some relationships between fields. It does not
    decide whether a domain, physics scheme, time step, or other scientific
    choice is appropriate for your research question.

## Start with a real example

The bundled smoke test contains:

```toml
schema_version = 1

[case]
description = "Athens, Georgia single-domain smoke test"

[namelist]
managed = true

[time]
start = 2026-09-30T00:00:00Z
end = 2026-09-30T06:00:00Z
forcing_interval_seconds = 10800

[forcing]
provider = "gfs"
product = "0p25"
cycle = 2026-09-30T00:00:00Z
forecast_hours = [0, 3, 6]

[forcing.subset]
west = 265
east = 288
north = 42
south = 25
```

The rest of the file describes the geography, model grid, time step, physics
suite, and output.

Before editing a case, you can ask wrfkit to check it without writing changes:

```bash
./wrfctl config --case my-case --check
```

For a higher-level read-only summary:

```bash
./wrfctl plan --case my-case
```

## TOML basics

A line such as:

```toml
time_step = 72
```

sets one value.

Square brackets start a section:

```toml
[model]
time_step = 72
```

Values in square brackets are arrays:

```toml
e_we = [101]
```

For nested domains, arrays can contain one value per domain.

Boolean values are lowercase:

```toml
restart = false
```

## Top-level fields

| Field | Meaning | Usually change it? |
| --- | --- | --- |
| `schema_version` | Version of the wrfkit TOML format | **No.** Keep `1` for the current format |
| `case.description` | Human-readable description of the experiment | Yes |

### `schema_version`

Current wrfkit accepts:

```toml
schema_version = 1
```

This is a format version, not a WRF version.

## `[namelist]`

### `managed`

```toml
[namelist]
managed = true
```

This controls whether wrfkit may update the TOML-owned settings in the two
native namelist files.

| Value | Behavior |
| --- | --- |
| `true` | wrfkit writes only the settings represented by TOML; other native namelist values are preserved |
| `false` | wrfkit does not modify either native namelist |

Even with `managed = false`, TOML can still contain wrfkit workflow settings
such as forcing-download information.

For most beginners, `true` is easier to use.

## `[time]`

This section defines the simulation period and the spacing of external weather
input.

### `start` and `end`

```toml
[time]
start = 2026-09-30T00:00:00Z
end   = 2026-09-30T06:00:00Z
```

Both times must include a UTC offset. A trailing `Z` means UTC.

wrfkit maps these values into the WPS start/end dates and the corresponding WRF
run time.

### `forcing_interval_seconds`

```toml
forcing_interval_seconds = 10800
```

This is the time spacing between external meteorological input files.

`10800` seconds = 3 hours.

The value must agree with the times supplied by `forecast_hours`. For example,
a six-hour experiment with three-hour forcing needs data at 0, 3, and 6 hours.

## `[forcing]`

This section tells wrfkit which external weather files to acquire.

### `provider`

```toml
provider = "gfs"
```

The current automatic provider is **GFS**.

### `product`

```toml
product = "0p25"
```

The current automatic GFS product is the 0.25-degree product.

### `cycle`

```toml
cycle = 2026-09-30T00:00:00Z
```

This is the GFS initialization time. Current GFS cycles are 00, 06, 12, and
18 UTC.

### `forecast_hours`

```toml
forecast_hours = [0, 3, 6]
```

These are the GFS lead times to download.

For a simulation from 00Z to 06Z with three-hour forcing, the required hours
are 0, 3, and 6.

## `[forcing.subset]`

This is the geographic box downloaded from the current GFS source.

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

The current downloader uses longitudes in the **0 to 360 degrees east**
convention. For example, 275°E is the same longitude as 85°W.

Choose a box large enough to cover the WRF domain and its required boundary
area.

## `[geography]`

```toml
[geography]
dataset = "wps-lowres-mandatory"
resolution = "lowres"
```

### `dataset`

Names the static WPS geography package used by the automatic workflow.

### `resolution`

Maps to WPS `geog_data_res`.

!!! warning
    The current automatic downloader supports the bundled **low-resolution
    smoke-test** geography. It is intended for workflow testing and education,
    not as a general research-grade geography choice.

## `[domain]`

This section describes the WRF grid.

### Number of domains

```toml
max_dom = 1
```

`1` means one domain. Nested experiments use more than one domain.

Many domain fields are arrays because each domain may need its own value.

### Parent/nesting fields

```toml
parent_id = [1]
parent_grid_ratio = [1]
i_parent_start = [1]
j_parent_start = [1]
```

| Field | Meaning |
| --- | --- |
| `parent_id` | which larger domain contains each domain |
| `parent_grid_ratio` | how much finer a nested grid is than its parent |
| `i_parent_start` | nest start position in the parent's west-east direction |
| `j_parent_start` | nest start position in the parent's south-north direction |

For a single domain, these values normally stay at their simple d01 values.

### Horizontal grid size

```toml
e_we = [61]
e_sn = [61]
```

These are the staggered grid dimensions:

- `e_we`: west-east grid dimension;
- `e_sn`: south-north grid dimension.

Larger values create a larger domain if grid spacing is unchanged.

### Vertical levels

```toml
e_vert = [45]
```

This is the number of full vertical levels, including the model top and
surface-related level structure used by WRF.

There is no single correct value for every study.

### Horizontal grid spacing

```toml
dx = 12000
dy = 12000
```

These are grid spacings in meters for projections such as Lambert,
Mercator, and polar stereographic.

`12000` means 12 km.

Smaller grid spacing gives finer detail but usually increases computational
cost strongly.

### Map projection and domain center

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
| `map_proj` | map projection used by WPS |
| `ref_lat` | reference latitude near the grid center |
| `ref_lon` | reference longitude near the grid center |
| `truelat1` | first true latitude for the projection |
| `truelat2` | second true latitude when used |
| `stand_lon` | standard longitude / central meridian |

Current WPS projection names include values such as `"lambert"`,
`"polar"`, `"mercator"`, and `"lat-lon"`.

The parser also accepts `pole_lat` and `pole_lon` when they are needed by
the selected projection.

### Additional domain fields

The convenience layer also accepts several lower-level domain settings, such as:

```toml
[domain]
parent_time_step_ratio = [1]
feedback = 1
smooth_option = 0
p_top_requested = 5000
```

These map directly to their WRF domain settings. They are more specialized, so
use the upstream WRF documentation when choosing values.

## `[model]`

### `time_step`

```toml
[model]
time_step = 72
```

This is the WRF integration time step in seconds.

A common WRF rule of thumb for typical real-data cases is no more than about
six times the horizontal grid spacing in kilometers. For a 12 km grid, 72 s is
therefore an upper rule-of-thumb value, not a guarantee of numerical stability.

If WRF reports CFL-related instability, a smaller time step may be needed.

## `[physics]`

### `suite`

```toml
[physics]
suite = "CONUS"
```

This maps to WRF's `physics_suite`.

A physics suite is a coordinated preset of parameterization choices. It is not
automatically the best choice for every location, resolution, season, or
research question.

If you need individual physics schemes, use the advanced WRF tables described
below.

## `[output]`

### `history_interval_minutes`

```toml
history_interval_minutes = 180
```

How often WRF writes history output, in minutes.

Smaller intervals produce more frequent output and usually require more
storage.

### `frames_per_outfile`

```toml
frames_per_outfile = 1
```

How many output times are stored in each WRF history file.

### `restart`

```toml
restart = false
```

Maps to WRF's restart switch.

### `restart_interval_minutes`

When restart mode is used, you can also set:

```toml
restart_interval_minutes = 1440
```

This maps to WRF's restart interval in minutes.

!!! warning
    wrfkit's complete restart/recovery workflow is not currently claimed as
    validated. The TOML field can map to the native namelist, but that is not
    the same thing as an end-to-end supported restart workflow.

## Lower-level control with `[advanced.*]`

The convenience fields above cover common settings. They do **not** try to
duplicate every option available in WRF and WPS.

Instead, wrfkit lets you write native namelist groups and keys directly.

### Advanced WRF example

```toml
[advanced.wrf.physics]
mp_physics = [8]
cu_physics = [1]
ra_lw_physics = [4]
ra_sw_physics = [4]
radt = [12]
```

This maps to the native WRF `&physics` group.

Another example:

```toml
[advanced.wrf.dynamics]
hybrid_opt = 2
diff_opt = [2]
km_opt = [4]
```

This maps to `&dynamics`.

### Advanced WPS example

```toml
[advanced.wps.geogrid]
geog_data_res = ["default"]
opt_geogrid_tbl_path = "."
```

This maps to the native WPS `&geogrid` group.

### Precedence

If a convenience field and an advanced field both write the same native
namelist key, the **advanced value wins**.

For example, if a convenience field chooses one physics value but
`[advanced.wrf.physics]` explicitly supplies the same native key, the advanced
setting takes priority.

### Any native group/key can be used

wrfkit intentionally does not keep a hard-coded list of every upstream namelist
option under `advanced.wrf` and `advanced.wps`.

That means a new or uncommon native key can be written without waiting for a
new wrfkit release:

```toml
[advanced.wrf.some_native_group]
some_native_key = 123
```

You are responsible for using a valid WRF/WPS group, key, type, and scientific
value.

## Raw escape hatch

Some Fortran namelist expressions cannot be represented cleanly as ordinary
TOML values. For those cases, wrfkit provides raw tables.

Example:

```toml
[advanced.wrf_raw.domains]
"eta_levels(1:3)" = "1.0, 0.5, 0.0"
```

The string on the right is inserted as native Fortran namelist syntax.

Use raw overrides only when normal TOML values are not enough.

## TOML type conversion

Normal advanced values are translated like this:

| TOML | Fortran namelist |
| --- | --- |
| `"text"` | quoted string |
| `12` | integer |
| `12.5` | floating-point number |
| `true` / `false` | `.true.` / `.false.` |
| `[1, 2, 3]` | comma-separated values |

## Safe editing workflow

When changing a research case, use this sequence:

```bash
# 1. edit
$EDITOR cases/my-case/case.toml

# 2. validate without writing namelists
./wrfctl config --case my-case --check

# 3. inspect the resolved experiment
./wrfctl plan --case my-case

# 4. prepare when the input-generating configuration is ready
./wrfctl prep --case my-case

# 5. run
./wrfctl run --case my-case
```

If you change `case.toml`, `namelist.wps`, or `namelist.input` after
preparation, `wrfctl run` reports that the prepared input predates the current
configuration. Re-run `prep` when the change requires new
`wrfinput`/`wrfbdy`.

## Where is the complete annotated template?

The repository contains:

```text
config/case.template.toml
```

It is the copyable, commented template for the current schema.

For the full list of upstream WRF/WPS namelist options, use the official WRF
Users' Guide. The `[advanced.*]` interface is designed to let those native
options pass through without wrfkit having to re-document every upstream
parameter.
