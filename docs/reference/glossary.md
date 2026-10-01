# What do these words mean?

You do not need to memorize this page. Use it when a word in another guide is
unfamiliar.

| Word | Plain-language meaning |
| --- | --- |
| **WRF** | The weather model itself. It calculates how the atmosphere changes over time. |
| **WPS** | The preparation tools that turn maps and external weather data into input WRF can use. |
| **Nix** | A tool that gives wrfkit a controlled software environment: compiler, MPI, NetCDF, and other libraries. |
| **rootless Nix** | Nix that works without administrator/root permission. Useful on shared HPC systems. |
| **MPI** | A way to split one model run into many cooperating processes so several CPU cores can work together. |
| **MPI rank** | One MPI worker process. A 16-rank run has 16 cooperating worker processes. |
| **Slurm** | The queue/scheduler on many HPC clusters. It decides when and where your job runs. |
| **login node** | The computer you first SSH into. Good for editing and submitting jobs; not for heavy computation. |
| **compute node** | A server assigned to do the actual heavy computation. |
| **allocation** | CPU, memory, node, and time resources Slurm has reserved for your job. |
| **sbatch** | Submit a script to Slurm and let it run when resources are available. |
| **interactive allocation** | A compute allocation where you receive a shell and type commands yourself. |
| **case** | One experiment's tracked configuration, such as `cases/athens-smoke`. |
| **workspace** | Generated files used while that case runs, under `.wrfkit/work/<case>`. |
| **namelist** | WRF/WPS's native text configuration format. The important files are `namelist.wps` and `namelist.input`. |
| **domain** | The geographic area and model grid you simulate. |
| **forcing** | External weather information used to initialize and drive the model boundaries. |
| **GFS** | NOAA's Global Forecast System; wrfkit currently uses it for the bundled real-data smoke path. |
| **geography/static data** | Terrain, land-use, soil, and similar spatial datasets that do not change every forecast hour. |
| **spin-up** | Early model time often allowed for the model state to adjust before analysis. |
| **WRF physics** | Parameterizations for processes such as clouds, radiation, surface exchange, and the boundary layer. |
| **wrfout** | The main WRF model output file. |
| **RSL logs** | WRF's per-rank diagnostic logs, usually named `rsl.out.*` and `rsl.error.*`. |

## A simple analogy

Think of a WRF experiment like cooking from a scientific recipe:

```text
namelists        = recipe
WPS              = preparing ingredients
real             = setting up the kitchen for this run
WRF              = cooking
wrfout           = finished result
Slurm            = person assigning you a kitchen
MPI ranks        = cooks working together
Nix              = making sure every cook has the same tools
wrfkit           = organizer connecting all of the above
```

The analogy is imperfect, but it is enough to understand the first-run
workflow.
