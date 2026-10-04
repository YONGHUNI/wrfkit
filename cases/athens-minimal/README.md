# athens-minimal

Minimal single-domain WRF/WPS workflow-validation case centered near Athens, Georgia.

The case uses `case.toml` for wrfkit-owned configuration. Its native
`namelist.wps` and `namelist.input` remain visible and are overlaid only
for values explicitly managed by TOML.

- ARW
- 1 domain
- 12 km grid spacing
- 61 x 61 grid points
- Lambert conformal projection
- WPS low-resolution mandatory static geography

The low-resolution geography is intentionally used only to validate the wrfkit
WPS execution path. It is not intended for research-quality or operational
forecasting.

From the repository root:

```bash
./wrfctl fetch geog
./wrfctl exec geogrid --case athens-minimal
```

A successful run should create `.wrfkit/work/athens-minimal/geo_em.d01.nc`.
The command is launched from the repository root; wrfkit creates and enters the
generated case workspace internally. The tracked case directory contains only
reproducible configuration. `GEOGRID.TBL`, `METGRID.TBL`, and the `geog`
link are staged automatically from wrfkit-managed data.

The case now uses a fixed GFS validation window: 2026-09-30 00 UTC through
06 UTC at 3-hour intervals. The forcing metadata is tracked in `case.toml`.
The files are fetched as a regional subset from the NOAA/NCEP NOMADS GFS
0.25-degree GRIB filter.

From the repository root:

```bash
./wrfctl fetch gfs --case athens-minimal
./wrfctl prepare gfs --case athens-minimal
./wrfctl exec ungrib --case athens-minimal
```

`prepare gfs` links the pinned WPS 4.7.0 `Vtable.GFS` and creates the native
`GRIBFILE.AAA`, `GRIBFILE.AAB`, and `GRIBFILE.AAC` links inside
`.wrfkit/work/athens-minimal`. A successful ungrib run should produce
`FILE:2026-09-30_00`, `FILE:2026-09-30_03`, and
`FILE:2026-09-30_06` in that workspace.

NOMADS is an operational, rolling service, so this fixed date is suitable for
the minimal validation case but is not a long-term archival fixture.


## WRF real-data stage

The case includes a minimal single-domain `namelist.input` aligned with the
00-06 UTC GFS/WPS window. Before running WRF programs, stage the runtime tables
and data from the pinned WRF 4.8.0 source tree:

```bash
./wrfctl prepare wrf --case athens-minimal
./wrfctl exec real --case athens-minimal
```

`prepare wrf` creates runtime-table/data links in
`.wrfkit/work/athens-minimal` while leaving the tracked `namelist.input` under
case control. A successful `real` run should create `wrfinput_d01` and
`wrfbdy_d01` in that workspace.

The `namelist.input` is intentionally a minimal validation configuration, not a
research-quality physics recommendation. It uses one 12 km domain, a 72 s time
step, 45 vertical levels, and WRF's `CONUS` physics suite.
