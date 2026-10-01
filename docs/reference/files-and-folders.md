# Files and folders

wrfkit separates **things you edit** from **things programs generate**.

## The short version

```text
cases/                 you edit and commit these
.wrfkit/work/          generated working files and model products
.wrfkit/logs/          run-by-run provenance and archived native logs
.wrfkit/data/          reusable downloaded input data
.wrfkit/install/       built WRF/WPS programs
```

## A case

```text
cases/my-case/
├── forcing.conf
├── namelist.wps
├── namelist.input
└── README.md
```

Treat this as the source of truth for the experiment.

## A workspace

```text
.wrfkit/work/my-case/
├── namelist.wps -> cases/my-case/namelist.wps
├── namelist.input -> cases/my-case/namelist.input
├── geo_em.*
├── FILE:*
├── met_em.*
├── wrfinput_d01
├── wrfbdy_d01
├── wrfout_d01_*
├── rsl.out.*
└── rsl.error.*
```

The exact set changes as the workflow progresses.

## Run logs

```text
.wrfkit/logs/my-case/
└── YYYYMMDD_HHMMSS_wrf/
    ├── command.txt
    ├── run.env
    ├── run.started
    └── native-logs.tar
```

The native WPS/WRF log files remain in the workspace and a run-specific snapshot
is stored in `native-logs.tar`.

## Reusable data

Examples:

```text
.wrfkit/data/geog/
.wrfkit/data/gfs/
```

These are separate from the tracked case so multiple runs can reuse downloaded
input data.

## Sapelo2 and /lscratch

The Sapelo2 profile currently uses node-local `/lscratch/$USER/.nix` for the
rootless Nix store.

Although the profile also declares a `scratch_root`, current WRF/WPS execution
workspaces still live under:

```text
<repository>/.wrfkit/work/<case>
```

Do not assume scientific outputs are automatically staged to `/lscratch`.
