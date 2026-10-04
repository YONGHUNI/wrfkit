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
| GFS acquisition and staging | **Validated** | Tested with the bundled smoke-test GFS window |
| Low-resolution validation geography | **Validated** | `athens-minimal`; intended for testing and education |
| High-resolution geography case configuration | **Implemented** | `athens-highres`; automatic acquisition is not implemented yet |
| WPS → `real` → WRF | **Validated** | Bundled `athens-minimal` workflow completed |
| Single-node interactive MPI | **Validated** | Tested during development |
| Single-node `sbatch` MPI | **Validated** | Sapelo2 batch run completed successfully |
| `wrfctl plan` | **Validated** | Tested on Lambda Vector and Sapelo2 |
| `wrfctl prep` through `real.exe` | **Validated** | Tested on Lambda Vector and Sapelo2 |
| `wrfctl run` | **Validated on Sapelo2** | Fresh Lambda regression is still pending |
| `case.toml` + native namelist overlay | **Validated** | Common fields and advanced passthrough have been exercised |
| Shared reusable `data_root` | **Validated on Sapelo2** | Geography and GFS were reused from external `/work` storage |
| Multi-node MPI | **Not validated** | Do not treat it as a supported research path yet |
| WRF restart/recovery workflow | **Not validated** | Individual namelist fields exist, but the complete workflow is not tested |
| Scratch-backed case workspace | **Not implemented** | Case workspaces currently stay with the repository |
| Automatic research-grade geography selection | **Planned** | Automatic prep currently uses the smoke-test geography path |

## What "validated" means

**Validated** means the workflow was actually executed in the named environment
and produced the expected program-level result.

It does **not** mean:

- every WRF namelist option has been tested;
- every HPC cluster will behave like Sapelo2;
- the smoke-test scientific setup is recommended for research;
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

The bundled `athens-minimal` case is a workflow test. For research, create a
new case and redesign its scientific settings.

## How to validate your own case

A new research case needs two kinds of checking.

### 1. Technical checks

Confirm that:

```text
geogrid completes
ungrib completes
metgrid completes
real creates wrfinput/wrfbdy
WRF reports SUCCESS COMPLETE WRF
expected wrfout files exist
run logs are archived
```

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
