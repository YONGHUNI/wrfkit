# athens-highres

Single-domain Athens validation case for WPS's high-resolution mandatory static geography.

This case intentionally keeps the same domain, time window, GFS forcing, WRF
physics, and output settings as `athens-minimal`. The controlled difference is
the static-geography profile:

```toml
[geography]
dataset = "wps-highres-mandatory"
resolution = "default"
```

That makes the pair useful for testing wrfkit's geography handling without
pretending that this is a complete scientific research template.

Current status:

- `wrfctl config --case athens-highres --check` validates the case.
- `wrfctl plan --case athens-highres` resolves the managed high-resolution path.
- `wrfctl fetch geog --case athens-highres` downloads, validates, caches, and
  installs the official high-resolution mandatory package.
- `wrfctl prep --case athens-highres` uses that acquisition path automatically
  and never falls back to the low-resolution package.
- The official high-resolution archive has completed the full
  `geogrid -> ungrib -> metgrid -> real -> wrf` path on both UGA Sapelo2 and
  Lambda Vector, including creation of `wrfinput_d01`, `wrfbdy_d01`, and
  `wrfout_d01_*`.

The downloader is covered by CI with a small local archive that has the same
expected directory structure. It avoids separate `tar -tzf` pre-scans and uses
the real extraction as the single gzip/tar integrity pass. Download, SHA-256,
extraction, and total acquisition times are printed so large-cluster runs can be
compared directly.

The word *high-resolution* here describes the source WPS static-geography
package, not the WRF model grid. This case still uses a 12 km, 61 x 61 WRF
domain. `geogrid` selects source fields according to the native
`GEOGRID.TBL` and `geog_data_res = 'default'`, then interpolates those static
fields onto the 12 km model grid in `geo_em.d01.nc`.

For a machine with shared persistent storage, configure `data_root` first so
the large geography tree and its source archive can be reused.
