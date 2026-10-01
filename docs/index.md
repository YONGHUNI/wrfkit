# wrfkit

**Run WRF without first becoming an expert in compilers, MPI, NetCDF, or Nix.**

wrfkit gives WRF and WPS a reproducible software environment, keeps each
experiment organized, and provides a tested single-node path for Linux and
Slurm HPC systems such as UGA Sapelo2.

[Start your first WRF run](tutorials/first-run.md){ .md-button .md-button--primary }
[See what is validated](validation.md){ .md-button }

!!! tip "You can start before you understand every acronym"
    If words such as **WRF**, **WPS**, **MPI**, **Slurm**, or **Nix** are new,
    that is fine. Follow the first-run tutorial first. The
    [glossary](reference/glossary.md) explains them in plain language when you
    need them.

## Pick what you want to do

<div class="grid cards" markdown>

-   **I have never run WRF before**

    ---

    Follow one guided run from cloning the repository to
    `SUCCESS COMPLETE WRF`.

    [First-run tutorial](tutorials/first-run.md)

-   **I need to run a job on Sapelo2**

    ---

    Use the validated one-node Slurm path and a ready-to-copy `sbatch`
    example.

    [Run WRF with sbatch](how-to/sapelo2-batch.md)

-   **I want to make my own experiment**

    ---

    Learn what belongs in a case, what wrfkit generates, and which scientific
    choices still belong to you.

    [Make a research case](how-to/research-case.md)

-   **Something failed**

    ---

    Start with the short error-to-action guide before reading long logs.

    [Troubleshooting](troubleshooting.md)

</div>

## The whole idea in one picture

```text
Your scientific settings
cases/<case>/
      |
      v
    wrfkit
      |
      +--> WPS prepares maps + weather input
      |        geogrid -> ungrib -> metgrid
      |
      +--> WRF prepares + runs the model
               real -> wrf
                         |
                         v
                    wrfout_d01_*
```

wrfkit tries to hide **computer setup complexity**, not **scientific choices**.
You still control the native WRF/WPS namelists.

## What is ready today?

The strongest supported path is currently:

```text
Linux x86_64
+ WRF 4.8.0 / WPS 4.7.0
+ rootless or normal Nix
+ one compute node
+ interactive or Slurm sbatch MPI
+ real-data GFS -> WPS -> real -> WRF
```

Multi-node MPI is not yet claimed as validated. See the
[validation matrix](validation.md) for the exact support boundary.

## If you are learning

A useful order is:

1. Do the [first-run tutorial](tutorials/first-run.md).
2. Read the [glossary](reference/glossary.md) only when a word blocks you.
3. Learn [where files go](reference/files-and-folders.md).
4. Read the [research-case guide](how-to/research-case.md) before changing the
   smoke test into a scientific experiment.
5. Use the [command reference](reference/commands.md) after the basic workflow
   makes sense.
