# What do these words mean?

You do not need to memorize these terms. Use this page when a word in another
guide is unfamiliar.

Terms are grouped by **meaning and workflow**, rather than alphabetically, so
related ideas stay together. External term links point to official
documentation, standards bodies, research-computing documentation, or another
authoritative reference. Terms that are specific to wrfkit link to this site's
own documentation.

## Weather modeling & WRF

### Core model and preprocessing

| Term | Plain-language meaning |
| --- | --- |
| [**WRF**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/overview.html) | The Weather Research and Forecasting model. It numerically simulates how the atmosphere changes over time. |
| [**WPS**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html) | The WRF Preprocessing System. It prepares geographical and meteorological input for real-data WRF simulations. |

### WPS preprocessing programs

| Term | Plain-language meaning |
| --- | --- |
| [**geogrid**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html) | Defines the model domain and interpolates static geographical data such as terrain and land use onto the model grid. |
| [**ungrib**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html) | Extracts meteorological fields from GRIB weather-data files and converts them into WPS intermediate files. |
| [**metgrid**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html) | Interpolates the meteorological fields prepared by ungrib onto the domains defined by geogrid. |

### WRF initialization and output

| Term | Plain-language meaning |
| --- | --- |
| [**real**](https://www2.mmm.ucar.edu/wrf/site/users_guide/real_initialization.html) | WRF's real-data initialization program. It turns `met_em.*` files into the initial and boundary files needed by WRF. |
| [**wrfout**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/output.html) | The standard WRF history/output files containing simulated atmospheric fields. |

### Scientific configuration and input data

| Term | Plain-language meaning |
| --- | --- |
| [**namelist**](https://www2.mmm.ucar.edu/wrf/users/wrf_users_guide/build/html/namelist_variables.html) | WRF/WPS's native text configuration format. The main files are `namelist.wps` and `namelist.input`. |
| [**domain**](https://www2.mmm.ucar.edu/wrf/site/documentation/users_guide/wps.html) | The geographic area and numerical grid that the model simulates. |
| [**forcing**](https://www2.mmm.ucar.edu/wrf/site/users_guide/real_initialization.html) | External atmospheric data used to provide initial and boundary conditions for a real-data simulation. |
| [**GFS**](https://www.emc.ncep.noaa.gov/emc/pages/numerical_forecast_systems/gfs.php) | NOAA/NCEP's Global Forecast System. wrfkit currently uses GFS data for its bundled real-data smoke workflow. |
| [**geography / static data**](https://www2.mmm.ucar.edu/wrf/site/geog_data.html) | Time-invariant terrestrial data such as terrain height, land use, soil categories, and related fields used by geogrid. |
| [**spin-up**](https://www.metoffice.gov.uk/binaries/content/assets/metofficegovuk/pdf/research/applied-science/precis/precis_handbook.pdf) | An early part of a model simulation allowed for model fields to adjust away from their initial state before the period used for analysis. |
| [**WRF physics**](https://www2.mmm.ucar.edu/wrf/users/wrf_users_guide/build/html/physics.html) | Parameterizations that represent processes such as clouds, radiation, surface exchange, and the planetary boundary layer. |
| [**GRIB**](https://confluence.ecmwf.int/spaces/MTG2US/pages/514756246/About+GRIB+data+format) | A WMO-standard binary format widely used to distribute gridded meteorological data. WPS ungrib reads GRIB input. |
| [**NetCDF**](https://www.unidata.ucar.edu/software/netcdf/) | A portable, self-describing format and software library widely used for array-oriented scientific data. WRF commonly reads and writes NetCDF files. |

## Computing & HPC

### Software environment

| Term | Plain-language meaning |
| --- | --- |
| [**Nix**](https://nix.dev/) | A package and environment system that lets wrfkit pin compilers, MPI, NetCDF, and other software dependencies reproducibly. |
| [**rootless Nix**](https://github.com/YONGHUNI/rootless-nix-bootstrap) | The no-administrator-privilege Nix setup used by wrfkit on systems such as shared HPC clusters. |

### Parallel computing

| Term | Plain-language meaning |
| --- | --- |
| [**MPI**](https://www.mpi-forum.org/) | Message Passing Interface, a standard for communication among multiple processes in a parallel program. |
| [**MPI rank**](https://www.mpi-forum.org/docs/) | One participating MPI process, identified by a rank number within an MPI communicator. A 16-rank WRF run has 16 cooperating MPI processes. |

### Cluster and scheduler

| Term | Plain-language meaning |
| --- | --- |
| [**Slurm**](https://slurm.schedmd.com/quickstart.html) | A cluster workload manager and job scheduler. It allocates resources, launches jobs, and manages the queue. |
| [**login node**](https://wiki.gacrc.uga.edu/wiki/Systems) | On Sapelo2, a node used for lightweight work such as editing files and submitting jobs. Heavy computation belongs on compute nodes. |
| [**compute node**](https://wiki.gacrc.uga.edu/wiki/Systems) | A cluster server assigned to perform the actual computation for a scheduled or interactive job. |
| [**allocation**](https://slurm.schedmd.com/quickstart.html) | A set of resources—such as nodes, CPUs, memory, and time—that Slurm reserves for a job. |
| [**sbatch**](https://slurm.schedmd.com/sbatch.html) | The Slurm command that submits a batch script for later execution by the scheduler. |
| [**interactive allocation**](https://slurm.schedmd.com/salloc.html) | Reserved compute resources that you use interactively from a shell rather than through a fully unattended batch script. Sapelo2 provides its own `interact` convenience command for this workflow. |

## wrfkit workflow & files

| Term | Plain-language meaning |
| --- | --- |
| [**wrfctl**](commands.md) | The main wrfkit command-line wrapper. It enters the managed environment and runs fetch, build, preparation, and execution tasks. |
| [**bootstrap**](../tutorials/first-run.md#step-3-prepare-nix) | The wrfkit setup step that makes a working Nix environment available when the machine does not already provide one. |
| [**case**](../how-to/research-case.md) | One experiment's tracked scientific configuration, such as `cases/athens-smoke`. |
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

    The analogy is intentionally simplified. Use the definitions above for the
    precise meaning.
