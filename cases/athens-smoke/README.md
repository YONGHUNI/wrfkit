# athens-smoke

Minimal single-domain WPS smoke case centered near Athens, Georgia.

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
./wrfctl exec geogrid --case athens-smoke
```

A successful run should create `cases/athens-smoke/geo_em.d01.nc`.
The command is intentionally launched from the repository root; wrfkit enters
the selected case directory internally.

The tracked `GEOGRID.TBL` and `METGRID.TBL` symlinks point to the ARW tables
from wrfkit's pinned WPS 4.7.0 source tree. Build or fetch WPS before running
this case.

The case now uses a fixed GFS smoke-test window: 2026-09-30 00 UTC through
06 UTC at 3-hour intervals. The forcing metadata is tracked in `forcing.conf`.
The files are fetched as a regional subset from the NOAA/NCEP NOMADS GFS
0.25-degree GRIB filter.

From the repository root:

```bash
./wrfctl fetch gfs --case athens-smoke
./wrfctl prepare gfs --case athens-smoke
./wrfctl exec ungrib --case athens-smoke
```

`prepare gfs` links the pinned WPS 4.7.0 `Vtable.GFS` and creates the native
`GRIBFILE.AAA`, `GRIBFILE.AAB`, and `GRIBFILE.AAC` links inside the case.
A successful ungrib run should produce `FILE:2026-09-30_00`,
`FILE:2026-09-30_03`, and `FILE:2026-09-30_06`.

NOMADS is an operational, rolling service, so this fixed date is suitable for
the immediate smoke test but is not a long-term archival fixture.
