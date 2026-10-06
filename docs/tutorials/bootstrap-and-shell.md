# Bootstrap and enter the wrfkit shell

This page explains the machine setup layer. Do this before worrying about WRF
science.

The recommended **interactive** mental model is:

```text
clone repository
      ↓
bootstrap the machine
      ↓
enter wrfctl shell
      ↓
build/check the pinned toolchain
      ↓
work on cases
```

Once you are inside the wrfkit shell, this documentation normally writes
commands as `wrfctl ...` rather than `./wrfctl ...`.

!!! note "The shell is a convenience, not a requirement"
    Running `./wrfctl ...` from the normal host shell is still supported.
    wrfctl enters the pinned Nix environment for commands that need it. The
    explicit shell is recommended for interactive work because it makes the
    active environment visible and gives you the same compiler, MPI, Python,
    WRF, and WPS tools for exploratory commands.

    Batch scripts should normally call `./wrfctl ...` directly instead of
    starting an interactive shell.

## What bootstrap does

`./bootstrap` prepares wrfkit's **machine-level execution environment**. It
does not choose your WRF domain or physics and it does not replace
`case.toml`.

Its responsibilities include:

- locating or preparing a usable Nix installation;
- selecting a standalone or Slurm-oriented machine profile;
- choosing rootless-Nix storage when needed;
- recording machine-level MPI policy;
- optionally recording a reusable `data_root`;
- saving machine configuration under
  `~/.config/wrfkit/bootstrap.conf`.

Scientific choices belong in a case. See
[Understand case.toml](../reference/case-toml.md).

## First setup on standalone Linux

From the repository root:

```bash
./bootstrap
```

When guided configuration is needed, choose the standalone workstation/server
path. wrfkit inspects the CPU capacity visible to the process and proposes an
MPI task count.

The proposed value is a starting point, not a benchmark result. You may keep a
fixed value or choose `auto` so wrfkit redetects a topology-aware standalone
rank count at runtime.

After bootstrap:

```bash
./wrfctl shell
```

The shell hook exports wrfkit's compiler/toolchain variables and places the
repository plus installed WRF/WPS binaries on `PATH`. An interactive Bash
prompt normally shows a `(wrfkit)` marker.

Inside that shell:

```bash
wrfctl doctor
wrfctl build all
```

Continue with [Your first WRF run](first-run.md).

## First setup on a Slurm cluster

Do not perform heavy environment realization, compilation, or WRF execution on
a shared login node. Obtain a compute allocation using your site's normal
method, return to the repository, then run bootstrap there.

For a generic Slurm site:

```bash
./bootstrap
./wrfctl shell
```

The guided setup can select the generic Slurm profile and a writable rootless
Nix store when the site needs one.

Site-specific scheduler options, filesystems, and policies are outside the
generic profile. UGA users should follow the
[UGA Sapelo2 guide](../single-node-guide.md).

## Sapelo2 profiles

The bootstrap script currently exposes three guided profile choices for Slurm
use:

| Profile | Intended use |
| --- | --- |
| `generic` | Slurm systems without Sapelo2-specific storage assumptions |
| `sapelo2` | Sapelo2 with node-local `/lscratch` rootless-Nix storage |
| `sapelo2-shared` | Sapelo2 shared-store path for cases that need the store visible across nodes/sessions |

The validated wrfkit execution boundary is still single-node. The existence of
a shared-store profile does not by itself make multi-node WRF a validated
workflow. See [Supported and validated](../validation.md).

## The machine configuration file

Guided setup writes:

```text
~/.config/wrfkit/bootstrap.conf
```

Supported keys include:

```ini
profile=...
store_root=...
backend=...
scratch_root=...
data_root=...
scheduler=none|slurm
require_allocation=true|false
mpi_launcher=auto|srun|mpirun|mpiexec|custom
mpi_tasks=N|auto
mpi_launcher_command=...
mpi_task_flag=...
```

Not every key is needed on every machine.

The bootstrap configuration is **machine policy**. Do not put experiment dates,
domain geometry, or physics choices there; those belong in
[case.toml](../reference/case-toml.md).

## Reusable data versus the Nix store

These are different concepts.

- `store_root` is about the Nix software environment.
- `data_root` is about reusable wrfkit data such as static geography and
  cached forcing.

For example, on an HPC system you may choose a persistent lab/work location for
data even when the rootless Nix store itself is temporary:

```ini
data_root=/work/my-lab/$USER/wrfkit-data
```

Case-specific generated files still live under
`.wrfkit/work/<case>` in the current design. See
[Files and folders](../reference/files-and-folders.md).

## Configuration precedence

Bootstrap documents this precedence:

```text
CLI
  > environment
  > selected config
  > bundled profile config
  > built-in fallback
```

That means a one-off command-line choice can override a saved machine profile,
while the saved profile remains the normal default.

Use:

```bash
./bootstrap --help
```

for the current command-line options before changing a saved setup.

## What `wrfctl shell` actually changes

The project `flake.nix` defines the interactive development shell. Today it
provides the pinned compiler/library environment plus utilities including
OpenMPI, NetCDF, Python with scientific packages, CMake, Git, and the WRF/WPS
build dependencies.

Inside the shell:

```bash
echo "$WRFKIT_NIX_SHELL"
which gcc
which mpirun
which python
which wrfctl
```

The shell does **not** mean WRF itself has already been built. That is what:

```bash
wrfctl build all
```

does.

If you want to change packages supplied by this shell, continue to
[Customize flake.nix](../how-to/customize-flake.md).

## Interactive shell versus batch

For interactive work:

```bash
./wrfctl shell
wrfctl plan --case my-case
wrfctl prep --case my-case
wrfctl run  --case my-case
```

For batch work, do not try to keep an interactive shell open. The batch script
can call the repository wrapper directly:

```bash
./wrfctl prep --case my-case
./wrfctl run  --case my-case
```

wrfctl handles entry into the project environment. See
[Run WRF with sbatch](../how-to/sapelo2-batch.md).

## Where to go next

- First execution: [Your first WRF run](first-run.md)
- Scientific configuration: [Understand case.toml](../reference/case-toml.md)
- Native stage-by-stage execution:
  [High-level and low-level workflows](../how-to/low-level-workflow.md)
- Environment customization: [Customize flake.nix](../how-to/customize-flake.md)
- Architecture: [How wrfkit works](../explanation/how-it-works.md)
