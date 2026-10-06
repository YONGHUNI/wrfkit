# UGA Sapelo2

This page contains only the Sapelo2-specific rules you need before following
the normal wrfkit workflow.

If you have never run wrfkit before, keep
[Your first WRF run](tutorials/first-run.md) open and use this page when it
mentions HPC or Slurm.

## The one rule to remember

**Do not build WRF/WPS or run WRF on an `ss-sub*` login node.**

A login node is shared by many users. Use it for lightweight work such as:

- SSH;
- editing small text files;
- Git operations;
- checking files;
- submitting jobs;
- checking job status.

Actual compilation and model execution should happen on a compute node.

## Interactive work

From a Sapelo2 login node, request a compute allocation:

```bash
interact -c 16 --mem=64G --time=02:00:00 --gres=lscratch:100
```

After the allocation starts, return to the repository:

```bash
cd ~/work/project/wrfkit
```

Then prepare the machine profile and enter the project shell:

```bash
./bootstrap --profile sapelo2
./wrfctl shell
```

Inside the `(wrfkit)` shell:

```bash
wrfctl doctor
wrfctl build all
```

The default Sapelo2 profile uses node-local `/lscratch` for its disposable
rootless-Nix store. That store may have to be recreated on a different compute
node. For the distinction between bootstrap, the Nix store, reusable data, and
the interactive shell, read
[Bootstrap and enter the wrfkit shell](tutorials/bootstrap-and-shell.md).

## The normal case workflow

Inside an appropriate compute allocation, the interactive documentation assumes
you have entered `./wrfctl shell`. Then:

```bash
wrfctl plan --case athens-minimal
wrfctl prep --case athens-minimal
wrfctl run  --case athens-minimal
```

You can still use `./wrfctl ...` directly outside the shell. Batch jobs should
use that direct form rather than trying to keep an interactive shell open.

For a first run, follow the full
[first-run tutorial](tutorials/first-run.md).

## Batch jobs

You may submit an `sbatch` script from a login node. Slurm then runs the
heavy work on a compute node.

The repository includes:

```text
examples/sapelo2-single-node.sbatch
```

For details, see [Run WRF with sbatch](how-to/sapelo2-batch.md).

## Where files should live

Sapelo2 has several storage systems with different purposes. wrfkit currently
keeps its case workspace with the repository, so choose the repository location
carefully.

In general:

| Storage | Good use |
| --- | --- |
| `/home/$USER` | source code, scripts, small/static files |
| lab `/work` | reusable files needed by jobs |
| `/scratch/$USER` | temporary shared job data |
| `/lscratch` | fast node-local temporary data |

Sapelo2 storage policies can change. Use current GACRC documentation when
deciding where long-lived or large research data should be stored.

## MPI: do not add another launcher

For the supported single-node Slurm path, wrfkit manages the launch topology.

Use:

```bash
./wrfctl run --case my-case
```

or, for low-level use:

```bash
./wrfctl exec wrf --case my-case
```

Do **not** wrap wrfkit in another multi-rank command such as:

```bash
srun -n 16 ./wrfctl exec wrf --case my-case
```

## Current boundary

The tested Sapelo2 path is **single-node** execution.

Multi-node MPI is not currently claimed as validated. Check
[Supported and validated](validation.md) before using a new execution mode for
research.

## Related pages

- Environment setup: [Bootstrap and enter the wrfkit shell](tutorials/bootstrap-and-shell.md)
- First complete run: [Your first WRF run](tutorials/first-run.md)
- Stage-by-stage debugging: [High-level and low-level workflows](how-to/low-level-workflow.md)
- Batch execution: [Run WRF with sbatch](how-to/sapelo2-batch.md)
- Current validation boundary: [Supported and validated](validation.md)
