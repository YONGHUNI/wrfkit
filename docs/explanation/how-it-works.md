# How wrfkit works

You can use wrfkit without understanding this page. Read it when you want to
know what the wrapper is doing for you.

## Three separate layers

```text
1. Software environment
   Nix pins compiler + MPI + NetCDF + WRF + WPS

2. Scientific configuration
   cases/<case>/case.toml
   cases/<case>/namelist.wps
   cases/<case>/namelist.input

3. Execution backend
   local shell or Slurm single-node execution
```

Keeping these layers separate is the main design idea.

For interactive work, `wrfctl shell` makes layer 1 explicit. The project
`flake.nix` defines that shell, while bootstrap records machine/site policy.
See [Bootstrap and enter the wrfkit shell](../tutorials/bootstrap-and-shell.md)
and [Customize flake.nix](../how-to/customize-flake.md).

## Why does `prep` exist if the individual commands still exist?

The native preparation chain contains several distinct programs and staging
steps. Those distinctions are useful when diagnosing a failure, but they are
usually plumbing rather than separate user intentions.

```text
Normal workflow:
  wrfctl prep --case NAME

Equivalent low-level path:
  fetch geography
  -> geogrid
  -> fetch forcing
  -> stage forcing
  -> ungrib
  -> metgrid
  -> stage WRF runtime data
  -> real
```

wrfkit therefore keeps both layers. `prep` orchestrates the case, while
`fetch`, `prepare`, and `exec` remain available when you need direct
control over one stage. `wrfctl config` resolves `case.toml` first and,
when allowed, overlays TOML-owned values onto the native namelists.

The complete stage-by-stage mapping, including what safety checks high-level
`prep`/`run` add beyond direct `exec`, is documented in
[High-level and low-level workflows](../how-to/low-level-workflow.md).

Reusable downloaded inputs may also be separated from a particular repository
with a machine-level `data_root`. Static geography and raw forcing are good
shared inputs because several cases can reuse the same source data. Generated
WPS/WRF products stay in each case workspace because they depend more directly
on that case's configuration.

For a plain-language tour of these capabilities, see [Features](../features.md).

## Why Nix?

WRF depends on a collection of compilers and libraries. On different computers,
those versions can differ.

Nix gives wrfkit a controlled software environment so a run does not silently
switch to whatever compiler, MPI, or NetCDF happens to be installed on the host.

On HPC systems where users do not have root permission, wrfkit can use rootless
Nix. Bootstrap handles the machine-facing policy; `flake.nix` describes the
project-facing software environment. Those are intentionally separate from
scientific case configuration.

## Why does Slurm launch only one child task first?

A naive rootless design can make every MPI rank enter Nix separately:

```mermaid
flowchart LR
    R0["MPI rank 0"] --> N0["Nix entry"]
    R1["MPI rank 1"] --> N1["Nix entry"]
    R2["MPI rank 2"] --> N2["Nix entry"]
    RX["MPI rank …"] --> NX["Nix entry"]
```

During development on Sapelo2 this led to repeated Nix evaluation, SQLite cache
contention, and UCX namespace errors.

The validated single-node design is instead:

```mermaid
%%{init: {"flowchart": {"nodeSpacing": 20, "rankSpacing": 30}}}%%
flowchart LR
    A["Slurm allocation<br/>N CPUs"]
    B["Child srun step<br/>1 task · N CPUs"]
    C["Enter rootless Nix once"]
    D["Pinned OpenMPI<br/>mpirun -np N"]
    E["N WRF ranks<br/>same Nix namespace"]

    A --> B --> C --> D --> E
```

Interactive allocations use the same basic bridge with the Slurm overlap option
needed by an already-running interactive step.

## Why separate case and workspace?

WRF/WPS naturally generate many files. If all of them lived beside the files you
edit, Git status and experiment provenance would become noisy.

So wrfkit treats:

```text
cases/<case>/          intentional scientific configuration
.wrfkit/work/<case>/   generated native execution workspace
```

as separate concepts.

## Why archive logs into one tar file?

WRF can create one pair of RSL files per MPI rank. Renaming many small files on
some shared HPC filesystems can be unexpectedly expensive.

wrfkit keeps native logs in the workspace and creates one per-run
`native-logs.tar` for persistent provenance.

For implementation details and future plans, see [Design notes](../design.md).

## Follow the layer you are changing

| If you want to change... | Start here |
| --- | --- |
| machine/site storage or MPI policy | [Bootstrap and enter the wrfkit shell](../tutorials/bootstrap-and-shell.md) |
| compilers, libraries, Python packages, pinned Nix inputs | [Customize flake.nix](../how-to/customize-flake.md) |
| domain, forcing, physics, output | [Understand case.toml](../reference/case-toml.md) |
| one WPS/WRF stage | [High-level and low-level workflows](../how-to/low-level-workflow.md) |
| complete research experiment | [Make a research case](../how-to/research-case.md) |
