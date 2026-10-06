# Validation notes

This page preserves the detailed regression record used while developing wrfkit.
It is intentionally separate from the short user-facing support matrix.

This page records what has been empirically exercised, separate from what is
merely implemented or planned.

## Current support boundary

| Capability | Status | Notes |
| --- | --- | --- |
| WRF 4.8.0 build | Validated | Clean `build all --jobs 16` regression completed on Lambda Vector and Sapelo2 |
| WPS 4.7.0 build | Validated | Serial WPS stage completed on Lambda Vector and Sapelo2; `geogrid`, `ungrib`, and `metgrid` installed |
| Rootless Nix on Sapelo2 | Validated | Default single-node profile uses node-local `/lscratch` |
| Static geography staging | Validated | Bundled low-resolution validation geography |
| GFS acquisition/staging | Validated | Fixed GFS validation window through NOMADS |
| `geogrid -> ungrib -> metgrid` | Validated | `athens-minimal` |
| `real -> wrf` | Validated | Produces WRF input/boundary/output files |
| Single-node interactive MPI | Validated | Tested with 16 and 24 ranks during development |
| Single-node `sbatch` MPI | Validated | 16-rank Sapelo2 run completed successfully |
| One-Nix-namespace Slurm bridge | Validated | Inner OpenMPI launch confirmed in batch |
| Per-run native log archive | Validated | `native-logs.tar` with current-run filtering |
| High-level `wrfctl prep` through `real` | Validated | `athens-minimal` completed through `real.exe` with verified `wrfinput`/`wrfbdy` on Lambda Vector and Sapelo2 |
| `wrfctl plan` / `prep --dry-run` | Validated | Read-only resolved-science and stage view exercised on Lambda Vector and Sapelo2 |
| WRF-safe MPI decomposition guard | Validated on Sapelo2 | 32 available tasks use 32 ranks for WPS and 30 ranks (5 x 6) for `real`/`wrf`; explicit unsafe `--ntasks 32` is rejected |
| High-level `wrfctl run` | Validated on Lambda Vector and Sapelo2 | Historical 12 km validations completed on both; the current 3 km `athens-highres` case is additionally validated on Sapelo2 |
| Preparation freshness guard | CI validated; stale detection live-validated on Sapelo2 | Historical warn-and-continue detection was exercised live; current policy blocks stale prep by default and requires `--allow-stale-prep` for intentional reuse |
| Optional shared `data_root` | Validated on Sapelo2 | External `/work` data root supplied through `WRFKIT_DATA_ROOT` was used for cached geography and GFS through `geogrid -> ungrib -> metgrid -> real` |
| GFS regional-subset cache identity | Implemented, not yet regression-validated | Cache path includes a request key derived from product and bounding box |
| TOML `case.toml` parser + namelist overlay | Validated | `--check` and managed overlay exercised on Lambda Vector and Sapelo2; unspecified native keys are preserved |
| TOML-driven forcing metadata | Validated | `athens-minimal` GFS date/cycle/hours/subset resolved from `case.toml` and completed acquisition/staging on Lambda Vector and Sapelo2 |
| Multi-node MPI | Not validated | Do not treat as supported research execution |
| WRF restart/recovery workflow | Not validated | Requires dedicated workflow testing |
| Scratch-backed execution workspace | Not implemented | `scratch_root` is currently configuration metadata |
| High-resolution mandatory geography downloader | Validated | Official package acquisition has been exercised, and the downloader remains covered by a local CI archive fixture |

## Clean build regression

The current build policy was re-tested from a clean generated state with:

```bash
./wrfctl clean
./wrfctl build all --jobs 16
```

The sequence completed successfully on both a standalone Lambda Vector Linux
workstation and a Sapelo2 compute node. In both environments, the final WPS
stage installed `geogrid`, `ungrib`, and `metgrid` and printed
`WPS build completed.`

The Sapelo2 WPS compilation printed compiler warnings while building
`read_geogrid.c`, but those warnings did not stop compilation or installation.
The final completion message, rather than the absence of warnings, is the
build-level success checkpoint.

## TOML + prep orchestration regression

The high-level preparation path was exercised on both the standalone Lambda
Vector system and Sapelo2 with:

```bash
./wrfctl prep --case athens-minimal
```

In both environments, `wrfctl config` reported the tracked native namelists as
unchanged, the low-resolution geography dependency was resolved, the three GFS
forecast hours were acquired from the TOML forcing definition, and
`geogrid`, `ungrib`, and `metgrid` all reported successful completion.
The final stage linked the WRF runtime data and `prep` completed normally.

Sapelo2 printed IEEE floating-point exception flags after `metgrid`, but
`metgrid` still emitted its explicit successful-completion marker and the
pipeline continued to WRF runtime staging. The flags are therefore recorded as
non-fatal output for this validation regression, not as a clean-output guarantee.

The extended high-level prep contract has now also been exercised through
`real.exe` on both Lambda Vector and Sapelo2. Prep verified the generated
`wrfinput`/`wrfbdy` artifacts and completed normally in both environments.
On Sapelo2, the stage-aware execution policy used all 32 available MPI tasks for
WPS while reducing only `real.exe` to 30 tasks with a 5 x 6 decomposition.

The Sapelo2 high-level `wrfctl run` path was then exercised with the same
automatic 32 -> 30 WRF adjustment. The preceding prep manifest was inspected
and contained the case fingerprint, hashes of both native namelists, pinned
WRF/WPS versions, and the preparation timestamp. `wrfctl run` accepted that
matching manifest, observed `SUCCESS COMPLETE WRF`, and verified a newly
created `wrfout_d01_*` before reporting success. This validates the positive
manifest path.

During development, the manifest initially used a warn-and-continue policy for
research flexibility. That historical path was exercised live on Sapelo2: a
tracked comment was appended to `namelist.input` after prep, the change was
detected, the existing `wrfinput`/`wrfbdy` were reused, and WRF still reached
`SUCCESS COMPLETE WRF`.

The current policy is stricter. High-level `wrfctl run` now refuses to launch
when `case.toml`, `namelist.wps`, or `namelist.input` no longer match the
prep manifest. The normal recovery is to run `wrfctl prep --case NAME` again.
Researchers who deliberately want to reuse older prepared inputs can opt in
with `--allow-stale-prep`. Missing prep state and pinned WRF/WPS version drift
remain hard errors and cannot be bypassed by that flag. The hard-stop and
explicit-override branches are covered in CI; a post-change live cluster
regression is still pending.

A shared-data regression was also completed on Sapelo2 using
`WRFKIT_DATA_ROOT=/work/whlab/$USER/wrfkit-data-test`. `wrfctl plan`
resolved both geography and the three cached GFS forcing files from that
external path. `wrfctl prep` then reported the same external data root,
completed `geogrid`, reused all three GFS files, completed `ungrib` and
`metgrid`, and finished `real.exe` with verified `wrfinput`/`wrfbdy`.
The generated case workspace remained project-local, confirming the intended
separation between reusable data and case-specific execution state.

The result does not validate other forcing providers, research-grade static
geography, or every advanced namelist passthrough.

## 3 km athens-highres regression (2026-10-06)

The tracked `athens-highres` fixture now represents a true 3 km WRF grid rather
than the earlier 12 km grid with only higher-resolution source geography. The
current resolved configuration is 241 x 241 horizontal grid points, 45 vertical
levels, a 3 km grid spacing, and an 18 s integration step. The CONUS physics
suite is retained while `cu_physics=0` and `radt=3` are applied as explicit
native overrides.

On Sapelo2, a fresh `wrfctl prep --case athens-highres` completed the full WPS
chain and `real.exe`, producing `wrfinput_d01` and `wrfbdy_d01`. The WRF
stages used 32 ranks with a 4 x 8 decomposition. A subsequent high-level
`wrfctl run --case athens-highres` reported a matching prep manifest and
completed with `SUCCESS COMPLETE WRF`. The run produced `wrfout_d01_*`, and
the 06 UTC output was readable by the project plotting environment. Terrain,
2 m temperature, and 10 m wind plots were inspected only as sanity checks; no
claim of observational or scientific validation is made from those figures.

On Lambda Vector, `config` and `plan` resolved the same 3 km case correctly.
The standalone automatic CPU policy selected 128 MPI tasks with an 8 x 16 WRF
decomposition, but OpenMPI/PRRTE rejected the launch because that environment
did not expose 128 launch slots. The 3 km Lambda end-to-end regression is
therefore still pending. This should not be confused with the earlier 12 km
high-resolution-geography Lambda runs, which did complete successfully.

## Single-node Slurm validation

The validated batch topology is:

```mermaid
%%{init: {"flowchart": {"nodeSpacing": 20, "rankSpacing": 30}}}%%
flowchart LR
    A["Slurm allocation<br/>1 node · N CPUs"]
    B["Child srun step<br/>1 task · N CPUs"]
    C["One rootless-Nix<br/>namespace entry"]
    D["Pinned OpenMPI<br/>mpirun -np N"]
    E["N WRF MPI ranks"]

    A --> B --> C --> D --> E
```

A Sapelo2 16-rank batch validation on an Intel Xeon Gold 6130 node completed
with Slurm state `COMPLETED`, exit code `0:0`, and WRF reporting
`SUCCESS COMPLETE WRF`.

The observed wall time of individual validation runs is intentionally not treated as
a benchmark. Short runs are sensitive to node state, filesystem metadata/cache
state, Nix evaluation caches, and other shared-system effects.

## What "validated" means here

Validated means that the path has been executed end-to-end in the stated
environment and produced the expected program-level result. It does not mean:

- every possible WRF namelist option is supported;
- every HPC site will behave identically;
- the minimal-case scientific configuration is recommended;
- numerical results are scientifically validated for a particular study.

## Validation checklist for a new research case

Before treating a new case as production-ready, confirm the workflow and the
science separately.

Workflow checks:

```text
geogrid completes
ungrib completes
metgrid completes
real creates wrfinput/wrfbdy
wrf reports SUCCESS COMPLETE WRF
expected wrfout files exist
provenance archive exists
```

Scientific checks should be defined by the study: domain adequacy, forcing,
physics, spin-up, stability, expected fields, and comparison against suitable
observations or reference data.


## Processor-decomposition regression note

During the first Sapelo2 regression of the extended `prep -> real` contract,
the scheduler supplied 32 MPI tasks for the 61 x 61 minimal domain. WRF's native
automatic decomposition selected 4 x 8 tasks, yielding a y-direction patch
width of 7 cells, and `real.exe` correctly aborted because WRF requires at
least 10 grid cells per decomposed patch direction.

The high-level workflow now mirrors WRF's automatic factor selection and checks
that native constraint before launching `real` or `wrf`. For this case,
32 requested tasks resolve to 30 WRF tasks with a 5 x 6 mesh.

On Sapelo2, `wrfctl plan --case athens-minimal` reported exactly that
32 -> 30 adjustment, while an explicit
`wrfctl prep --case athens-minimal --ntasks 32` stopped before native execution
and reported 30 tasks (5 x 6) as the safe alternative.

The automatic path was then exercised without `--ntasks`: `geogrid` and
`metgrid` used all 32 available MPI tasks, while `real.exe` and `wrf.exe`
launched with 30 tasks. `prep` completed with verified `wrfinput_d01` and
`wrfbdy_d01`; `run` then completed with `SUCCESS COMPLETE WRF` and a new
`wrfout_d01_*`. This validates the stage-aware decomposition path end to end
on Sapelo2.
