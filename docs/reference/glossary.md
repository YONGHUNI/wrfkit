# What do these words mean?

You do not need to memorize these terms. Use this page when a word in another
guide is unfamiliar.

Terms are grouped by **meaning and workflow**, rather than alphabetically, so
related ideas stay together. External links point to official documentation,
standards bodies, or established research-computing documentation and open in a
new tab. Terms that are specific to wrfkit link to this site's own documentation.

## Weather modeling & WRF

These terms appear together in the WPS → WRF workflow. If you want to see the
whole sequence first, use the [first-run tutorial](../tutorials/first-run.md).

### Core model and preprocessing

| Term | Plain-language meaning |
| --- | --- |
| [**WRF**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/overview.html){ target="_blank" rel="noopener noreferrer" } | The Weather Research and Forecasting model. It numerically simulates how the atmosphere changes over time. |
| [**WPS**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html){ target="_blank" rel="noopener noreferrer" } | The WRF Preprocessing System. It prepares geographical and meteorological input for real-data WRF simulations. |

### WPS preprocessing programs

| Term | Plain-language meaning |
| --- | --- |
| [**geogrid**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html){ target="_blank" rel="noopener noreferrer" } | Defines the model domain and interpolates static geographical data such as terrain and land use onto the model grid. |
| [**ungrib**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html){ target="_blank" rel="noopener noreferrer" } | Extracts meteorological fields from GRIB weather-data files and converts them into WPS intermediate files. |
| [**metgrid**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html){ target="_blank" rel="noopener noreferrer" } | Interpolates the meteorological fields prepared by ungrib onto the domains defined by geogrid. |

### WRF initialization and output

| Term | Plain-language meaning |
| --- | --- |
| [**real**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/real_initialization.html){ target="_blank" rel="noopener noreferrer" } | WRF's real-data initialization program. It turns `met_em.*` files into the initial and lateral-boundary files needed by WRF. |
| [**wrfout**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/output.html){ target="_blank" rel="noopener noreferrer" } | The standard WRF history/output files containing simulated atmospheric fields. |

### Scientific configuration and input data

| Term | Plain-language meaning |
| --- | --- |
| [**namelist**](https://www2.mmm.ucar.edu/wrf/users/wrf_users_guide/build/html/namelist_variables.html){ target="_blank" rel="noopener noreferrer" } | WRF/WPS's native text configuration format. The main files are `namelist.wps` and `namelist.input`. |
| [**domain**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html){ target="_blank" rel="noopener noreferrer" } | The geographic area and numerical grid that the model simulates. |
| [**forcing / meteorological input**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/real_initialization.html){ target="_blank" rel="noopener noreferrer" } | In wrfkit, *forcing* means external analysis or forecast data, such as GFS, that WPS and `real` process to create initial and lateral boundary conditions. WRF documentation more often describes this as meteorological input or external analysis/forecast data. |
| [**GFS**](https://www.emc.ncep.noaa.gov/emc/pages/numerical_forecast_systems/gfs.php){ target="_blank" rel="noopener noreferrer" } | NOAA/NCEP's Global Forecast System. wrfkit currently uses GFS data for its bundled real-data validation workflow. |
| [**geography / static data**](https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html){ target="_blank" rel="noopener noreferrer" } | Time-invariant terrestrial data such as terrain height, land use, soil categories, and related fields used by geogrid. |
| [**spin-up**](https://www2.mmm.ucar.edu/wrf/site_linked_files/tutorials/wrf_best_practices.pdf){ target="_blank" rel="noopener noreferrer" } | An early part of a simulation during which model fields adjust away from their initial state before the period used for analysis. |
| [**WRF physics**](https://www2.mmm.ucar.edu/wrf/users/wrf_users_guide/build/html/physics/physics.html){ target="_blank" rel="noopener noreferrer" } | Parameterizations that represent atmospheric processes such as clouds, radiation, surface exchange, and the planetary boundary layer. |
| [**GRIB**](https://codes.ecmwf.int/grib/format/grib2/regulations/){ target="_blank" rel="noopener noreferrer" } | A standardized binary code used to exchange and store gridded meteorological information. WPS `ungrib` reads GRIB input. |
| [**NetCDF**](https://www.unidata.ucar.edu/software/netcdf/){ target="_blank" rel="noopener noreferrer" } | A set of software libraries and machine-independent, self-describing data formats widely used for array-oriented scientific data. WRF commonly reads and writes NetCDF files. |

## Computing & HPC

### Software environment

| Term | Plain-language meaning |
| --- | --- |
| [**Nix**](https://nix.dev/manual/nix/2.35/){ target="_blank" rel="noopener noreferrer" } | A package manager that lets wrfkit construct controlled software environments containing pinned compilers, MPI, NetCDF, and other dependencies. |
| [**rootless Nix**](https://github.com/YONGHUNI/rootless-nix-bootstrap){ target="_blank" rel="noopener noreferrer" } | The no-administrator-privilege Nix setup used by wrfkit on systems such as shared HPC clusters. |

### Parallel computing

| Term | Plain-language meaning |
| --- | --- |
| [**MPI**](https://www.mpi-forum.org/){ target="_blank" rel="noopener noreferrer" } | Message Passing Interface, a standard for communication among multiple processes in a parallel program. |
| [**MPI rank**](https://www.mpi-forum.org/docs/mpi-4.1/mpi41-report/node187.htm){ target="_blank" rel="noopener noreferrer" } | One participating MPI process, identified by a rank number within an MPI communicator. A 16-rank WRF run has 16 cooperating MPI processes. |

### HPC clusters

| Term | Plain-language meaning |
| --- | --- |
| [**HPC**](https://docs.hpc.shef.ac.uk/en/latest/hpc/what-is-hpc.html){ target="_blank" rel="noopener noreferrer" } | High-performance computing: using powerful computing resources, often many CPUs or nodes working together, to run calculations that would be too large or slow for an ordinary computer. |
| [**cluster**](https://www.hpc.caltech.edu/docs/documentation/glossary.html){ target="_blank" rel="noopener noreferrer" } | A group of networked computers operated together as a shared computing system. HPC clusters commonly include login or service nodes plus many compute nodes. |
| [**node**](https://www.hpc.caltech.edu/docs/documentation/glossary.html){ target="_blank" rel="noopener noreferrer" } | One computer in a cluster. A node may serve a specialized role, such as providing user access or running computational workloads. |
| [**login node**](https://www.hpc.caltech.edu/docs/documentation/glossary.html){ target="_blank" rel="noopener noreferrer" } | A shared access point used on many HPC clusters for SSH, file management, job preparation, and job submission. Heavy computation normally runs on compute nodes. Login nodes are a common cluster design, not a requirement imposed by Slurm itself. |
| [**compute node**](https://www.hpc.caltech.edu/docs/documentation/glossary.html){ target="_blank" rel="noopener noreferrer" } | A cluster server intended to perform the actual computational workload. Scheduler-managed jobs are assigned resources on one or more compute nodes. |

### Slurm scheduling

| Term | Plain-language meaning |
| --- | --- |
| [**Slurm**](https://slurm.schedmd.com/overview.html){ target="_blank" rel="noopener noreferrer" } | A workload manager used on many HPC clusters. It manages resources, queues jobs, and launches work on allocated nodes. |
| [**partition**](https://slurm.schedmd.com/overview.html){ target="_blank" rel="noopener noreferrer" } | A logical group of Slurm nodes that acts like a job queue with its own limits and policies. |
| [**job**](https://slurm.schedmd.com/overview.html){ target="_blank" rel="noopener noreferrer" } | A user's request for resources and work to run under Slurm for a specified period of time. |
| [**allocation**](https://slurm.schedmd.com/job_launch.html){ target="_blank" rel="noopener noreferrer" } | The compute resources Slurm reserves for a job, such as nodes, CPUs, memory, and time. |
| [**job step**](https://slurm.schedmd.com/job_launch.html){ target="_blank" rel="noopener noreferrer" } | A set of tasks launched inside an existing Slurm job allocation. wrfkit's single-node bridge creates a child job step before starting MPI ranks. |
| [**sbatch**](https://slurm.schedmd.com/sbatch.html){ target="_blank" rel="noopener noreferrer" } | The Slurm command that submits a batch script to the scheduler. |
| [**srun**](https://slurm.schedmd.com/srun.html){ target="_blank" rel="noopener noreferrer" } | The Slurm command used to launch tasks or job steps. wrfkit uses a child `srun` step internally for its validated single-node Slurm path. |
| [**interactive job / allocation**](https://slurm.schedmd.com/salloc.html){ target="_blank" rel="noopener noreferrer" } | Reserved compute resources used interactively from a shell rather than through a fully unattended batch script. Sapelo2 provides its own `interact` convenience command for this workflow. |

## wrfkit workflow & files

| Term | Plain-language meaning |
| --- | --- |
| [**wrfkit**](../index.md) | This project: a reproducible environment and workflow layer around WRF/WPS that manages software setup, case workspaces, execution, and provenance without hiding the scientific namelists. |
| [**wrfctl**](commands.md) | The main wrfkit command-line wrapper. It enters the managed environment and runs fetch, build, preparation, and execution tasks. |
| [**bootstrap**](../tutorials/first-run.md#step-3-prepare-the-wrfkit-environment) | The wrfkit setup step that makes a working Nix environment available when the machine does not already provide one. |
| [**case**](../how-to/research-case.md) | One experiment's tracked scientific configuration, such as `cases/athens-minimal`. |
| [**workspace**](files-and-folders.md) | The generated working directory for a case, under `.wrfkit/work/<case>`, where WPS/WRF intermediate files and model products live. |
| [**RSL logs**](../how-to/check-run.md) | WRF's per-rank runtime logs, normally named `rsl.out.*` and `rsl.error.*`; wrfkit also archives them per run for provenance. |

## A simple analogy

!!! tip "If these terms still feel abstract"
    Think of a WRF experiment like cooking from a scientific recipe.

    | wrfkit / WRF term | Analogy |
    | --- | --- |
    | namelist | recipe |
    | WPS | preparing ingredients |
    | real | setting up the kitchen for this run |
    | WRF | cooking |
    | wrfout | finished result |
    | Slurm | assigning you a kitchen |
    | MPI ranks | cooks working together |
    | Nix | making sure everyone has the same tools |
    | wrfkit | organizer connecting everything |

    Every term on the left is defined above. The analogy is intentionally
    simplified; use the glossary definitions for the precise meaning.
