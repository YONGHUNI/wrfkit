# Caveats and safe patterns

This page collects the limitations that matter most when moving from a smoke
test to research use.

## Quick reference

| Caveat | Safe pattern |
| --- | --- |
| Sapelo2 login nodes are not compute nodes | Build/run inside an allocation; submit `sbatch` from the login node |
| wrfkit owns the single-node MPI launch | Call `./wrfctl exec wrf` directly inside the job |
| `athens-smoke` is not a scientific template | Revisit all scientific configuration for each study |
| `scratch_root` is not yet the execution workspace | Expect current work products under `.wrfkit/work/<case>` |
| Default Sapelo2 Nix storage is node-local | Bootstrap per allocated node when needed |
| Multi-node MPI is not validated | Stay on one node for supported research runs |
| WRF success is not scientific validation | Inspect model fields and experiment design |

## 1. Login node versus compute node

**Avoid**

```bash
# ss-sub2
./bootstrap --profile sapelo2
./wrfctl build all
./wrfctl exec wrf --case my-case
```

**Use instead for interactive setup**

```bash
interact -c 16 --mem=64G --time=02:00:00 --gres=lscratch:100

cd ~/work/project/wrfkit
./bootstrap --profile sapelo2
./wrfctl build all
```

**Use instead for batch research runs**

```bash
# Run this submission command from the login node.
WRFKIT_CASE=my-case sbatch examples/sapelo2-single-node.sbatch
```

Submitting `sbatch` from a login node is normal; the heavy work occurs on the
compute node assigned by Slurm.

## 2. Do not add a second MPI launcher

**Avoid**

```bash
srun -n 16 ./wrfctl exec wrf --case my-case
```

For the supported single-node Slurm path, use:

```bash
./wrfctl exec wrf --case my-case
```

wrfkit already creates the child Slurm step and then uses its pinned OpenMPI
inside one Nix namespace.

Why this matters: an earlier one-Nix-entry-per-rank topology caused repeated Nix
evaluation, SQLite cache contention, and UCX namespace errors. The current
single-node bridge was introduced specifically to avoid that topology.

## 3. The smoke case is a workflow fixture

`athens-smoke` currently uses a small 12 km, 61 x 61, 45-level,
single-domain configuration with low-resolution WPS geography and the WRF
`CONUS` physics suite.

That is enough to exercise the pipeline. It is not evidence that those choices
are appropriate for another location, process, season, or research question.

**Avoid**

```text
copy athens-smoke
-> change dates
-> call it a research experiment
```

**Use instead**

```text
copy configuration as a starting point
-> redesign domain and resolution
-> choose and justify physics
-> set forcing and spin-up
-> test numerical stability
-> validate the resulting fields
```

## 4. `scratch_root` is not yet the workspace location

The Sapelo2 profile declares:

```text
scratch_root=/lscratch/$USER/wrfkit
```

but the current execution workspace remains:

```text
<repository>/.wrfkit/work/<case>
```

Do not assume WPS/WRF products are automatically staged to `/lscratch`.
Scratch-backed workspaces require an explicit stage-in/stage-out policy so that
scientific outputs are not lost when node-local storage disappears.

## 5. The default Sapelo2 Nix store is disposable

The default profile uses:

```text
/lscratch/$USER/.nix
```

That makes environment realization fast and node-local, but it is not a
cross-node persistent software installation. A batch script may safely call:

```bash
./bootstrap --profile sapelo2
```

If Nix is already usable on the allocated node, bootstrap exits successfully
without reinstalling it.

## 6. Multi-node is a separate support boundary

This is within the validated scope:

```bash
#SBATCH --nodes=1
#SBATCH --ntasks=16
```

This is not yet claimed as validated:

```bash
#SBATCH --nodes=2
#SBATCH --ntasks=64
```

Multi-node rootless Nix introduces a different environment-distribution and MPI
problem. The repository contains design work for that path, but research use
should stay within a single node until multi-node validation is completed.

> [!WARNING]
> A code path existing in `wrfctl` does not by itself mean that the execution
> mode is supported. Use [validation.md](validation.md) as the support boundary.

## 7. Model completion is not scientific validation

`SUCCESS COMPLETE WRF` establishes that WRF reached normal program completion.
It does not establish that the experiment is physically meaningful.

For research runs, validate at least the forcing, domain, physics configuration,
spin-up, expected spatial/temporal patterns, missing values, and output
completeness before analysis.
