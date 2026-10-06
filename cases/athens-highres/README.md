# athens-highres

Single-domain Athens validation case for a true 3 km WRF grid using WPS's
high-resolution mandatory static geography.

The current fixture is intentionally more demanding than `athens-minimal`:

```text
grid spacing:       3 km
grid dimensions:    241 x 241
vertical levels:    45
integration step:   18 s
forcing:            GFS 0.25 degree, 2026-09-30 00Z, f000/f003/f006
geography:          wps-highres-mandatory / default
physics suite:      CONUS
cumulus override:   cu_physics = 0
radiation interval: radt = 3
```

The 241 x 241 grid keeps approximately the same horizontal span as the earlier
12 km, 61 x 61 Athens validation grid: 240 intervals at 3 km and 60 intervals
at 12 km are both about 720 km. The purpose is to exercise a genuinely finer
WRF model grid, not merely finer source geography.

This remains a validation fixture, not a ready-made research configuration.
The domain, forcing, physics, spin-up, and numerical choices must be justified
again for a real study.

## Validation status

On UGA Sapelo2, the current 3 km case completed the full
`geogrid -> ungrib -> metgrid -> real -> wrf` path with 32 MPI ranks for the
WRF stages using a 4 x 8 decomposition. `real.exe` created `wrfinput_d01`
and `wrfbdy_d01`, and `wrf.exe` reported `SUCCESS COMPLETE WRF` and created
`wrfout_d01_*`.

Basic diagnostic plots of terrain height, 2 m temperature, and 10 m wind were
also inspected as a sanity check. That confirms that the output is readable
and spatially plausible; it is not a scientific validation against
observations.

On Lambda Vector, the 3 km configuration and execution plan resolve correctly,
but the current standalone automatic task policy requested 128 MPI ranks while
OpenMPI/PRRTE exposed fewer launch slots. The resulting 128-rank launch was
rejected before model execution. A full 3 km Lambda regression therefore
remains pending with a compatible explicit rank count or an adjusted standalone
auto-task policy.

Earlier Lambda Vector runs that completed successfully used the older 12 km
high-resolution-geography version of this case. They validate the geography
and workflow history, but they are not evidence of a completed 3 km Lambda
run.

For machines with persistent shared storage, configure `data_root` so the
large geography tree and cached forcing can be reused across clones and cases.
