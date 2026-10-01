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

The tracked `GEOGRID.TBL` symlink points to the ARW table from wrfkit's pinned
WPS 4.7.0 source tree. Build or fetch WPS before running this case.

The dates in `namelist.wps` are placeholders at this stage; geogrid uses the
domain/static-data configuration and does not require meteorological forcing.
They will be replaced by a fixed GFS smoke-test window when ungrib/metgrid is
added.
