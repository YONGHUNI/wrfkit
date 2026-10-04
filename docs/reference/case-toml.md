# case.toml configuration

`case.toml` is the single wrfkit-facing configuration file for a scientific
case. It covers input-data acquisition and common WPS/WRF settings while keeping
the native `namelist.wps` and `namelist.input` visible.

## Ownership

```toml
[namelist]
managed = true
```

With `managed=true`, `wrfctl config` updates only values represented in
TOML. Every other native namelist setting is preserved. With `managed=false`,
wrfkit never modifies either native namelist; TOML still controls wrfkit-specific
behavior such as forcing acquisition.

## Common structure

```toml
schema_version = 1

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
```

The repository's `config/case.template.toml` is the annotated template. Its
comments explain each current convenience field, show example values, and mark
upstream defaults or recommendations where WRF/WPS documents them.

## Advanced native passthrough

Any native group/key can be expressed without waiting for a wrfkit convenience
field:

```toml
[advanced.wrf.physics]
mp_physics = [8]
cu_physics = [1]
ra_lw_physics = [4]
ra_sw_physics = [4]
radt = [12]
bldt = [0]

[advanced.wrf.dynamics]
hybrid_opt = 2
diff_opt = [2]
km_opt = [4]

[advanced.wps.geogrid]
opt_geogrid_tbl_path = "."
```

The table after `advanced.wrf` or `advanced.wps` becomes the native
namelist group. Unknown/new upstream keys are intentionally accepted. If a
convenience field and an advanced field target the same native key, the advanced
value wins.

Normal TOML strings, numbers, booleans, and arrays are converted to Fortran
namelist syntax. For unusual syntax, use the raw escape hatch:

```toml
[advanced.wrf_raw.domains]
"eta_levels(1:3)" = "1.0, 0.5, 0.0"
```

## Validate

```bash
./wrfctl config --case my-case --check
```

This parses TOML, checks current cross-field constraints, and reports the
planned WPS/WRF overlays without writing files. To apply them:

```bash
./wrfctl config --case my-case
```

`wrfctl prep --case my-case` invokes the configuration step automatically.

For a read-only view closer to the scientific intent than the raw override
count, use:

```bash
./wrfctl plan --case my-case
```

It prints the simulation period, forcing/cycle/hours/subset, geography, domain
dimensions, timestep, physics suite, output interval, and native override
counts, followed by the high-level stages. `prep --dry-run` uses the same
planning path.

A successful high-level prep continues through `real.exe`, verifies
`wrfinput_d0*` and `wrfbdy_d01`, and records a preparation fingerprint.
`wrfctl run` compares that record with the current `case.toml` and native
namelists. Case/namelist changes are reported as warnings and the run may
continue with the existing prepared inputs; a missing manifest or WRF/WPS
version mismatch remains a hard error.

!!! note "Implementation boundary"
    The namelist passthrough is intentionally broad, but automatic data
    acquisition is still narrower. The current provider is GFS 0.25° and the
    automatic geography downloader is still the low-resolution smoke-test
    package. See the validation matrix for what has been exercised end-to-end.
