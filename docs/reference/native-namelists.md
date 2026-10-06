# Native WRF/WPS namelist options

wrfkit's convenience schema is intentionally not a complete reimplementation
of every WRF/WPS namelist option.

When the upstream manual documents a valid native option that wrfkit does not
expose as a convenience field, use the `advanced` passthrough layer.

Start with [Understand case.toml](case-toml.md) if you need the general TOML
syntax or the standard `time/domain/geography/forcing/model/physics/output`
sections first.

## The mapping rule

The table name tells wrfkit which native namelist file and group to modify:

```text
[advanced.wrf.<group>]  →  &<group> in namelist.input
[advanced.wps.<group>]  →  &<group> in namelist.wps
```

For example:

```toml
[advanced.wrf.physics]
mp_physics = [8]
cu_physics = [0]
radt = [3]
```

maps to native `&physics` values in `namelist.input`.

Likewise:

```toml
[advanced.wps.geogrid]
geog_data_res = ["30s+default"]
opt_geogrid_tbl_path = "."
```

maps to `&geogrid` in `namelist.wps`.

## Translating an upstream manual entry

Suppose an upstream manual shows a group conceptually like:

```fortran
&some_good_stuff
 manual_said = 1,
 how_about_this = .true.,
/
```

Do **not** invent a new wrfkit top-level section:

```toml
# Wrong interface
[some_good_stuff]
manual_said = 1
how_about_this = true
```

If `&some_good_stuff` is really a valid WRF namelist group, write:

```toml
[advanced.wrf.some_good_stuff]
manual_said = 1
how_about_this = true
```

For WPS, use `advanced.wps` instead.

!!! warning
    The example group above is illustrative. wrfkit intentionally allows
    passthrough names it does not know, but that does not make a made-up group
    valid in WRF/WPS. The upstream model still decides whether the group, key,
    type, and value are valid.

## TOML to Fortran values

Ordinary passthrough values are converted as follows:

| TOML | Native namelist form |
| --- | --- |
| `"text"` | quoted Fortran string |
| `12` | integer |
| `12.5` | floating-point number |
| `true` / `false` | `.true.` / `.false.` |
| `[1, 2, 3]` | comma-separated values |

TOML Booleans are lowercase. `True` and `False` are not valid TOML Boolean
literals.

Many WRF fields are domain-dependent. If the upstream manual expects one value
per domain, use an array with the appropriate number/order of entries.

## Convenience fields versus advanced fields

The normal wrfkit layer handles common experiment-facing concepts:

```toml
[domain]
dx = 3000
dy = 3000

[physics]
suite = "CONUS"
```

The native layer handles the full upstream surface:

```toml
[advanced.wrf.physics]
cu_physics = [0]
radt = [3]
```

If both layers target the same native key, the **advanced value wins**.

Keep all `[advanced.*]` tables at the end of `case.toml`. That makes the
boundary between the friendly schema and native overrides visible during code
review.

## Common WRF groups

Examples of direct native groups include:

```toml
[advanced.wrf.time_control]
input_from_file = [true]
io_form_history = 2

[advanced.wrf.domains]
p_top_requested = 5000
parent_time_step_ratio = [1]
feedback = 1
smooth_option = 0

[advanced.wrf.physics]
mp_physics = [8]
cu_physics = [0]
ra_lw_physics = [4]
ra_sw_physics = [4]

[advanced.wrf.dynamics]
hybrid_opt = 2
diff_opt = [2]
km_opt = [4]

[advanced.wrf.bdy_control]
spec_bdy_width = 5
specified = [true]

[advanced.wrf.namelist_quilt]
nio_tasks_per_group = 0
nio_groups = 1
```

These are examples of syntax and mapping, not universal scientific
recommendations.

## Common WPS groups

Examples:

```toml
[advanced.wps.share]
wrf_core = "ARW"
active_grid = [true]

[advanced.wps.geogrid]
geog_data_res = ["default"]
opt_geogrid_tbl_path = "."

[advanced.wps.ungrib]
out_format = "WPS"
prefix = "FILE"

[advanced.wps.metgrid]
fg_name = ["FILE"]
opt_metgrid_tbl_path = "."
```

## Options that wrfkit does not know yet

The passthrough layer is deliberately open-ended:

```toml
[advanced.wrf.some_real_future_group]
some_new_option = 2
```

wrfkit does not require that group/key to be hard-coded in its convenience
schema.

This is how the project avoids duplicating the entire upstream manual and how
new model options can remain usable between wrfkit releases.

The trade-off is responsibility: wrfkit cannot fully validate unknown native
keys. Check the manual that matches the WRF/WPS version you are actually using.

## Raw escape hatch

Some native Fortran syntax cannot be represented cleanly by ordinary TOML
values. For those cases:

```text
[advanced.wrf_raw.<group>]
[advanced.wps_raw.<group>]
```

insert the right-hand TOML string verbatim.

Example:

```toml
[advanced.wrf_raw.domains]
"eta_levels(1:3)" = "1.0, 0.5, 0.0"
```

Use raw mode only when ordinary TOML conversion is insufficient. It bypasses
the normal type conversion and therefore requires more care.

## What wrfkit rejects

The convenience schema is strict on purpose.

These are rejected:

- unknown top-level wrfkit sections;
- unknown fields inside convenience sections;
- unsupported `advanced` families.

This catches mistakes such as:

```toml
[physcs]
suite = "CONUS"
```

or:

```toml
[physics]
suit = "CONUS"
```

The open-ended region begins **below** the supported families:

```text
advanced.wrf.<group>      arbitrary native WRF group/key
advanced.wps.<group>      arbitrary native WPS group/key
advanced.wrf_raw.<group>  raw WRF values
advanced.wps_raw.<group>  raw WPS values
```

## Validate after adding a manual option

Inside the [wrfkit shell](../tutorials/bootstrap-and-shell.md):

```bash
wrfctl config --case my-case --check
wrfctl plan --case my-case
```

Then render the managed values:

```bash
wrfctl config --case my-case
```

Inspect the native files:

```bash
git diff -- cases/my-case/namelist.wps cases/my-case/namelist.input
```

This confirms what wrfkit rendered. It still does not prove that the upstream
model accepts the option or that the scientific value is appropriate.

The next technical validation is to run the relevant native stage. Use
[High-level and low-level workflows](../how-to/low-level-workflow.md) to choose
the appropriate `exec` command.

## Why not expose every option as a convenience field?

A convenience field is most useful when wrfkit can add something beyond
renaming the native key, for example:

- cross-field validation;
- domain-length checks;
- clearer units;
- provider-aware behavior;
- safer defaults or diagnostics.

If wrfkit merely copied every upstream namelist key into another schema, it
would create a second WRF manual that must track every model release.

The intended policy is therefore:

```text
common + meaningfully validated → convenience field
valid but uncommon/new          → advanced native passthrough
special Fortran syntax          → raw passthrough
```

## Related pages

- [Understand case.toml](case-toml.md)
- [Make a research case](../how-to/research-case.md)
- [High-level and low-level workflows](../how-to/low-level-workflow.md)
- [wrfctl command reference](commands.md)
- [Customize flake.nix](../how-to/customize-flake.md)
