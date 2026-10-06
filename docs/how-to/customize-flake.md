# Customize `flake.nix`

`flake.nix` defines wrfkit's reproducible **software environment**. Edit it
when you intentionally want to change the compiler/library/tool environment,
not when you want to change a WRF experiment.

For experiment dates, domain geometry, physics, or output settings, use
[case.toml](../reference/case-toml.md).

## What the current flake controls

The repository currently uses `flake.nix` to define:

- the pinned nixpkgs input;
- the pinned WPS source revision;
- the WRF 4.8.0 release archive and its fixed hash;
- the development-shell packages;
- Python packages available in the shell;
- compiler environment variables;
- wrfkit/WRF/WPS paths added to `PATH`;
- the `(wrfkit)` interactive prompt marker.

The related lock state is stored in `flake.lock`.

## Enter the environment before experimenting

For normal interactive use:

```bash
./wrfctl shell
```

See [Bootstrap and enter the wrfkit shell](../tutorials/bootstrap-and-shell.md)
if the machine has not been prepared yet.

You can inspect the current environment with:

```bash
which gcc
which gfortran
which mpirun
python --version
```

## Add a Python package

The current flake has a block like:

```nix
(python3.withPackages (ps: with ps; [
  matplotlib
  netcdf4
  numpy
  xarray
]))
```

To add a package that exists in the selected nixpkgs Python package set, add it
to that list. For example:

```nix
(python3.withPackages (ps: with ps; [
  matplotlib
  netcdf4
  numpy
  pandas
  xarray
]))
```

Exit the old shell and enter a new one so Nix realizes the changed environment:

```bash
exit
./wrfctl shell
python -c "import pandas; print(pandas.__version__)"
```

A package name must actually exist in the pinned nixpkgs revision. If Nix
reports an unknown attribute, check the package name rather than adding an
unrelated pip installation and assuming the environment is still identical.

## Add a general command-line/build package

The shell package list is:

```nix
packages = with pkgs; [
  ...
]
```

A new nixpkgs package can be added there. After editing, re-enter the shell and
verify the executable:

```bash
exit
./wrfctl shell
which <program>
```

## Changing nixpkgs is a toolchain change

The current input is pinned to a specific nixpkgs commit. Changing it can alter
compiler, MPI, NetCDF, Python, and transitive library versions at once.

Treat that as a project-level reproducibility change:

1. edit the input deliberately;
2. update `flake.lock` deliberately when the input graph changes;
3. enter a fresh shell;
4. run `wrfctl doctor`;
5. rebuild WRF/WPS as needed;
6. rerun the validation cases before claiming the new environment is supported.

wrfctl normally invokes Nix with `--no-write-lock-file`, so ordinary command
execution should not silently rewrite the lock file.

## WRF and WPS versions need coordinated changes

Do **not** assume that changing only:

```nix
wrfVersion = "..."
wpsVersion = "..."
```

is enough.

The current project also carries version assumptions in wrfctl/build logic,
source fetching, validation records, and documentation. A WRF/WPS version bump
therefore needs a coordinated code change plus a fresh build and regression
validation.

For WRF, the flake also pins the release archive hash:

```nix
wrfArchive = pkgs.fetchurl {
  url = "...";
  hash = "sha256-...";
};
```

A new upstream archive requires the correct new fixed-output hash. Do not
replace it with an arbitrary value just to make evaluation proceed.

WPS is currently a non-flake Git source input pinned to a release commit. The
build copies that immutable source into wrfkit-managed project state because
the WPS build can write into its source tree.

## Editing `shellHook`

The shell hook currently exports wrfkit version/source variables, compiler
variables, PATH entries, and the interactive prompt marker.

Changes here affect every interactive wrfkit shell. Keep shellHook changes
portable and avoid machine-specific absolute paths. Machine-specific storage
belongs in bootstrap configuration; scientific settings belong in cases.

## Test an environment edit

A practical sequence is:

```bash
# edit flake.nix
$EDITOR flake.nix

# leave any old environment
exit

# realize the new development shell
./wrfctl shell

# inside it
wrfctl doctor
```

If the change affects compilers or libraries used to build WRF/WPS, rebuild
before trusting old binaries:

```bash
wrfctl clean
wrfctl build all
```

Then run at least the supported validation workflow appropriate to the change.
See [Supported and validated](../validation.md).

!!! warning "clean removes generated build/install state"
    `wrfctl clean` is not required after every harmless shell-package
    addition. Use it when you intentionally need a clean WRF/WPS rebuild.

## What should not go into `flake.nix`

Do not put these there:

- simulation start/end dates;
- WRF domain center or grid spacing;
- GFS cycle/forecast hours;
- physics choices;
- history output interval;
- cluster-specific data paths that belong in bootstrap configuration.

Use the right layer:

```text
flake.nix                  software environment shared by the project
bootstrap.conf             machine/site policy
cases/<name>/case.toml     experiment-facing configuration
namelist.*                 complete native WRF/WPS configuration
```

For the architecture behind those layers, read
[How wrfkit works](../explanation/how-it-works.md).

## Related pages

- [Bootstrap and enter the wrfkit shell](../tutorials/bootstrap-and-shell.md)
- [Understand case.toml](../reference/case-toml.md)
- [High-level and low-level workflows](low-level-workflow.md)
- [Files and folders](../reference/files-and-folders.md)
