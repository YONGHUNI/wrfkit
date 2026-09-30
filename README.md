# wrfkit

`wrfkit` is an experimental reproducible environment and workflow layer for the
[Weather Research and Forecasting (WRF) Model](https://github.com/wrf-model/WRF).

The project is intended for researchers who need WRF but do not want to manage
compiler, MPI, NetCDF, CMake, or Linux-distribution differences manually.

> Hide the system complexity, not the scientific configuration.

## Current status

This repository is an early MVP. The first milestone is deliberately narrow:

- WRF **4.8.0**
- Linux **x86_64**
- GNU C/C++/Fortran toolchain
- OpenMPI-enabled WRF build
- NetCDF-C / NetCDF-Fortran
- WRF CMake workflow (`configure_new` / `compile_new`)
- normal Nix or rootless Nix on machines without administrator access
- single-node MPI as the initial execution target

Not yet claimed as supported:

- WPS
- automated `namelist.wps` / `namelist.input` generation
- YAML configuration frontend
- multi-node MPI portability across HPC systems
- Slurm execution abstraction
- WRF-Chem / WRFDA

Those are planned after the base build has been validated on ordinary Linux and
UGA Sapelo2.

## Quick start

If Nix is already available:

```bash
git clone git@github.com:YONGHUNI/wrfkit.git
cd wrfkit

./wrfctl doctor
./wrfctl fetch
./wrfctl build
```

`wrfctl` enters the pinned Nix development environment automatically. You do
not need to run `nix develop` yourself.

To open the development shell explicitly:

```bash
./wrfctl shell
```

### Machine without Nix

Run:

```bash
./bootstrap
```

The wrapper installs rootless Nix through
[`YONGHUNI/rootless-nix-bootstrap`](https://github.com/YONGHUNI/rootless-nix-bootstrap)
when a normal `nix` command is not already available.

The bootstrap wrapper supports configuration profiles and does not require the
user to remember rootless-Nix store paths.

## Sapelo2

Do **not** run the first-time environment setup or WRF compilation on an
`ss-sub*` login node. Obtain a compute allocation first, then run the setup from
the compute node.

Example:

```bash
interact -c 16 --mem=64G --time=02:00:00 --gres=lscratch:100

cd ~/work/project/wrfkit
./bootstrap --profile sapelo2
./wrfctl doctor
./wrfctl build
```

For reproducible/manual use, explicitly selecting `--profile sapelo2` is recommended. If no profile is supplied, `./bootstrap` still attempts Sapelo2 auto-detection as a convenience fallback.

On Sapelo2, the explicit profile loads the bundled configuration:

```text
config/bootstrap/sapelo2.conf
```

The default Sapelo2 profile now uses the fast, disposable node-local store:

```text
/lscratch/$USER/.nix
```

This is intentional for the current single-node MVP: the Nix store can be
recreated for each allocation and prioritizes local I/O speed over persistence.

If a shared store is needed later (for example while testing multi-node
workflows), use:

```bash
./bootstrap --profile sapelo2-shared
```

which loads `config/bootstrap/sapelo2-shared.conf` and uses:

```text
/scratch/$USER/.nix
```

A personal override can be stored in:

```text
~/.config/wrfkit/bootstrap.conf
```

For example:

```ini
profile=sapelo2
store_root=/lscratch/$USER/.nix
backend=auto
```

## Build layout

Generated files are kept outside the tracked source tree:

```text
.wrfkit/
├── src/WRF-4.8.0/
├── build/wrf-4.8.0/
└── install/wrf-4.8.0/
    └── bin/
        ├── real
        └── wrf
```

The official WRF 4.8.0 release archive is fetched through Nix with its published
SHA-256 digest. This avoids accidentally using GitHub's automatically generated
"Source code" archives, which WRF 4.8.0 explicitly warns do not contain the
mandatory bundled external code required for compilation.

## Commands

```text
./wrfctl doctor          check the Nix-provided WRF toolchain
./wrfctl fetch           extract the pinned WRF 4.8.0 source
./wrfctl build           configure and compile MPI-enabled EM_REAL
./wrfctl build --jobs N  compile with N parallel build jobs
./wrfctl clean           remove generated build/install files
./wrfctl shell           enter the Nix development shell
```

The source tree is preserved by `clean`; use `rm -rf .wrfkit/src` when a complete
source reset is needed.

## Reproducibility boundary

The current MVP pins:

- the nixpkgs Git revision in `flake.nix`;
- the WRF release version and release-archive SHA-256;
- the WRF CMake configuration used by `scripts/build-wrf.sh`.

Nix does **not** make the host kernel, Slurm, network fabric, or HPC interconnect
reproducible. Multi-node MPI integration therefore remains a separate validation
task for each HPC backend.

## Planned configuration model

The planned workflow will support two first-class scientific-configuration modes
when a case is initialized:

```text
1) YAML frontend
   case.yaml -> generated namelist.wps + namelist.input

2) Native WRF configuration
   edit namelist.wps + namelist.input directly
```

Both modes will converge on the same WPS/WRF execution pipeline. YAML mode is
intended to expose WRF's scientific configuration rather than hide it: defaults,
documentation, validation, and comments will be generated from a schema, while
the final native namelist files will always be preserved for provenance.

See [`docs/design.md`](docs/design.md) for the working design notes.
