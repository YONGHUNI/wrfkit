# Supported and validated

This page answers one question:

**Which wrfkit workflows have actually been tested?**

A feature being present in the code does not automatically mean it has been
tested end to end.

## Supported path at a glance

| Capability | Status | What that means |
| --- | --- | --- |
| WRF 4.8.0 build | **Validated** | Clean build completed on Lambda Vector and UGA Sapelo2 |
| WPS 4.7.0 build | **Validated** | `geogrid`, `ungrib`, and `metgrid` built successfully |
| Rootless Nix on Sapelo2 | **Validated** | Tested with the current single-node Sapelo2 profile |
| GFS acquisition and staging | **Validated** | Tested with the bundled validation GFS window |
| Low-resolution validation geography | **Validated** | `athens-minimal`; intended for testing and education |
| High-resolution mandatory geography acquisition | **Validated** | Official package acquisition and staging have been exercised; CI also covers the downloader with a local archive fixture |
| `case.toml` -> native namelist rendering | **Validated + CI guarded** | Tracked namelists are regenerated in CI and must remain unchanged; the 3 km fixture values are pinned by assertions |
| WPS -> `real` -> WRF | **Validated** | Bundled real-data workflow has completed on Lambda Vector and Sapelo2 |
| 3 km `athens-highres` on Sapelo2 | **Validated** | 241 x 241, 3 km, 18 s case completed `prep` and `run`; WRF used 32 ranks with a 4 x 8 decomposition |
| 3 km `athens-highres` on Lambda Vector | **Pending end-to-end** | Config/plan resolve correctly, but the observed 128-rank automatic launch exceeded PRRTE's available slots |
| Single-node interactive MPI | **Validated** | Tested during development |
| Single-node `sbatch` MPI | **Validated** | Sapelo2 batch run completed successfully |
| `wrfctl plan` | **Validated** | Tested on Lambda Vector and Sapelo2 |
| `wrfctl prep` through `real.exe` | **Validated** | Tested on Lambda Vector and Sapelo2; current 3 km case validated on Sapelo2 |
| `wrfctl run` | **Validated** | Success-marker and new-output checks have completed on Lambda Vector and Sapelo2; current 3 km Lambda regression is still pending |
| Shared reusable `data_root` | **Validated on Sapelo2** | Geography and GFS were reused from external `/work` storage |
| Preparation freshness detection | **Validated on Sapelo2** | Live stale-case detection was exercised during development |
| Preparation freshness hard guard | **CI validated; live regression pending** | High-level `run` now blocks stale prep by default; `--allow-stale-prep` is an explicit escape hatch |
| Multi-node MPI | **Not validated** | Do not treat it as a supported research path yet |
| WRF restart/recovery workflow | **Not validated** | Individual namelist fields exist, but the complete workflow is not tested |
| Scratch-backed case workspace | **Not implemented** | Case workspaces currently stay with the repository |

## What "validated" means

**Validated** means the workflow was actually executed in the named environment
and produced the expected program-level result.

It does **not** mean:

- every WRF namelist option has been tested;
- every HPC cluster will behave like Sapelo2;
- a validation-case scientific setup is recommended for research;
- successful execution proves the weather simulation is scientifically valid.

## The main boundary for new users

If you want the least surprising path today, stay within:

```text
Linux x86_64
WRF 4.8.0
WPS 4.7.0
normal or rootless Nix
GFS real-data input
one compute node
local MPI or single-node Sapelo2 Slurm
```

The bundled `athens-minimal` and `athens-highres` cases are workflow and
regression fixtures. For research, create a new case and redesign its
scientific settings.

## How to validate your own case

A new research case needs two kinds of checking.

### 1. Technical checks

Confirm that:

```text
case.toml renders to the tracked/native namelists as expected
geogrid completes
ungrib completes
metgrid completes
real creates wrfinput/wrfbdy
wrf reports SUCCESS COMPLETE WRF
expected wrfout files exist
run logs are archived
```

If you edit a case after `prep`, the normal high-level `run` now stops rather
than silently mixing current namelists with older `wrfinput`/`wrfbdy`. Re-run
`prep`, or use `--allow-stale-prep` only when that reuse is deliberate.

[Check whether a run succeeded](how-to/check-run.md)

### 2. Scientific checks

These depend on your research question. They can include:

- domain placement and size;
- forcing quality;
- physics choices;
- spin-up;
- numerical stability;
- expected spatial and temporal patterns;
- missing values;
- comparison with suitable observations or reference data.

wrfkit can help keep the experiment reproducible, but it cannot decide whether
those scientific choices are correct.

## Detailed regression history

The longer development record, including MPI decomposition tests, preparation
manifest behavior, and shared-data regressions, is kept in
[Validation notes](development/validation-notes.md).
