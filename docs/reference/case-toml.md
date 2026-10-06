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
[domain]          # where the WRF grid is and how large/fine it is
[geography]       # static WPS geography
[forcing]         # which weather data drives the model
[forcing.subset]  # which part of that weather data to download
[model]           # numerical integration settings
[physics]         # physics preset
[output]          # how often WRF writes output
```

When those are not enough, use `[advanced.wrf.*]` or `[advanced.wps.*]`
to write lower-level native namelist options directly. The normal sections are
ordered as experiment definition → domain → inputs → model → output; native
`[advanced.*]` overrides belong at the end so the abstraction boundary stays
visible.

## A minimal example

The bundled Athens minimal validation case looks like this:

```toml
schema_version = 1

[case]
description = "Athens, Georgia minimal single-domain validation case"

[namelist]
managed = true

[time]
start = 2026-09-30T00:00:00Z
end   = 2026-09-30T06:00:00Z
forcing_interval_seconds = 10800

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

[geography]
dataset = "wps-lowres-mandatory"
resolution = "lowres"

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

## TOML syntax and wrfkit schema

A `case.toml` file uses standard TOML syntax. The important distinction is
between **TOML syntax** and the **wrfkit schema**:

- TOML decides whether the text is a valid TOML document.
- wrfkit decides whether a top-level section or convenience field belongs to
  the supported case schema.
- WRF/WPS decide whether a native `[advanced.*]` namelist group/key/value is
  actually valid for the model version.

### Values

Strings use quotes:

```toml
suite = "CONUS"
```

Integers and floating-point values are unquoted:

```toml
time_step = 18
ref_lat = 33.95
```

TOML Booleans are lowercase:

```toml
restart = false
managed = true
```

`True` and `False` are **not** TOML Boolean literals.

Arrays use square brackets:

```toml
forecast_hours = [0, 3, 6]
e_we = [241]
e_sn = [241]
```

WRF settings that vary by domain often use one array element per domain.
Follow the upstream WRF/WPS documentation for the expected number and meaning
of values.

TOML also supports date/time values. wrfkit requires an explicit UTC offset for
case times:

```toml
start = 2026-09-30T00:00:00Z
end   = 2026-09-30T06:00:00Z
```

A trailing `Z` means UTC.

Comments begin with `#`:

```toml
time_step = 18  # seconds
```

### Tables

A section such as:

```toml
[model]
time_step = 18
```

creates the `model` table.

A nested section:

```toml
[forcing.subset]
west = 265
east = 288
south = 25
north = 42
```

creates `subset` inside `forcing`.

Native passthrough tables use the same TOML nesting:

```toml
[advanced.wrf.physics]
cu_physics = [0]
radt = [3]
```

Here `wrf` identifies the native model family and `physics` maps to
`&physics` in `namelist.input`.

### The supported top-level schema

The current schema accepts these top-level sections/keys:

```text
schema_version
case
namelist
time
domain
geography
forcing
model
physics
output
advanced
```

Unknown top-level sections and unknown fields inside the convenience tables are
rejected. This is deliberate: a typo such as:

```toml
[physcs]
suite = "CONUS"
```

should fail rather than silently do nothing.

For a setting taken directly from the WRF/WPS manual, use the native
passthrough layer instead of inventing another wrfkit top-level table.

For example, this is **not** the intended interface:

```toml
[some_good_stuff]
manual_said = 1
how_about_this = true
```

If the upstream WRF manual really defines a namelist group named
`&some_good_stuff`, write:

```toml
[advanced.wrf.some_good_stuff]
manual_said = 1
how_about_this = true
```

wrfkit intentionally does not hard-code every possible native group/key under
`advanced.wrf` or `advanced.wps`. That lets newer or uncommon WRF/WPS
options be used without waiting for a new wrfkit convenience field.

!!! warning "Passthrough does not certify the upstream option"
    wrfkit can render an arbitrary native group/key, but it cannot guarantee
    that the name, type, range, or scientific value is valid for your WRF/WPS
    version. Check the upstream manual. A made-up group can still be rejected
    later by the native program.

### Three levels of configuration

A useful mental model is:

```text
1. wrfkit convenience layer
   [time], [domain], [geography], [forcing], [model], [physics], [output]
          ↓
   common settings + wrfkit validation

2. native passthrough layer
   [advanced.wrf.<group>]
   [advanced.wps.<group>]
          ↓
   arbitrary native namelist groups/keys

3. raw native layer
   [advanced.wrf_raw.<group>]
   [advanced.wps_raw.<group>]
          ↓
   verbatim Fortran namelist values when ordinary TOML conversion is not enough
```

Prefer level 1 when wrfkit provides the field. Use level 2 for valid manual
options that are not convenience fields. Use level 3 only for syntax that
cannot be represented normally.

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

For the built-in minimal validation case:

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

The tracked `athens-highres` case now uses the same general Athens region and
validation forcing window but a 3 km, 241 x 241 WRF grid with high-resolution
mandatory geography. It is no longer a controlled geography-only pair with the
12 km `athens-minimal` case.

wrfkit can automatically acquire this managed package. The official archive is
stored alongside the geography data so a shared `data_root` can reuse it across
repository clones. The downloader validates the tar/gzip archive, checks the
expected mandatory-field directories, records the archive SHA-256 for
provenance, and installs the extracted tree atomically.

The official high-resolution package has now been exercised in the current
validation workflow. The downloader also remains covered in CI with a local
archive fixture. See [Supported and validated](../validation.md) for the
current environment-specific boundary.

`resolution` is not forced to `"default"`. A researcher may keep WPS's native
selector freedom, for example:

```toml
resolution = "30s+default"
```

The small low-resolution validation package is different: because it only contains the
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

That limitation is intentional. Reproducing the entire upstream WRF/WPS
namelist surface as a second wrfkit-specific schema would create another manual
to keep synchronized with every model release. Instead, frequently used fields
can become convenience settings when wrfkit can add useful validation, while
the native passthrough remains open-ended.

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
**advanced value wins**. Keep advanced tables at the end of the file so this
override boundary remains obvious during review.

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

The documentation's default interactive workflow is to enter the pinned shell
once, then work with `wrfctl` directly:

```bash
./wrfctl shell
```

Inside the `(wrfkit)` shell:

```bash
# 1. edit
$EDITOR cases/my-case/case.toml

# 2. validate without writing native namelists
wrfctl config --case my-case --check

# 3. inspect the resolved experiment
wrfctl plan --case my-case

# 4. render + prepare inputs
wrfctl prep --case my-case

# 5. run WRF
wrfctl run --case my-case
```

If the scientific configuration changes after preparation, the freshness guard
normally stops `run` until you prepare again. See
[High-level and low-level workflows](../how-to/low-level-workflow.md) for the
exact stage mapping and the explicit stale-prep override boundary.

## Complete annotated template

The repository also contains a copyable template:

```text
config/case.template.toml
```

It includes additional advanced examples and comments.

For native WRF/WPS options beyond wrfkit's convenience layer, use the official
WRF documentation together with the `[advanced.*]` interface.

## Related pages

- Machine setup and shell: [Bootstrap and enter the wrfkit shell](../tutorials/bootstrap-and-shell.md)
- Build a real experiment: [Make a research case](../how-to/research-case.md)
- Inspect every WPS/WRF stage: [High-level and low-level workflows](../how-to/low-level-workflow.md)
- Change the software environment: [Customize flake.nix](../how-to/customize-flake.md)
- Command syntax: [wrfctl command reference](commands.md)
