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

- `wrfctl config --case athens-highres --check` is supported.
- `wrfctl plan --case athens-highres` resolves the managed high-resolution path.
- automatic download of `wps-highres-mandatory` is not implemented yet;
  therefore high-level `prep` stops before `geogrid` instead of falling back
  to low-resolution data.

Once the high-resolution downloader is implemented, this case is intended to be
the first end-to-end validation fixture for that path.
