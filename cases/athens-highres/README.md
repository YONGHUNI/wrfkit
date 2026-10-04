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
- `wrfctl prep --case athens-highres` now uses that acquisition path
  automatically and never falls back to the low-resolution package.

The downloader is covered by CI with a small local archive that has the same
expected directory structure. A live run with the full official archive through
WPS/real is still pending.

For a machine with shared persistent storage, configure `data_root` first so
the large geography tree and its source archive can be reused.
