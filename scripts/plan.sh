#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: ./wrfctl plan --case NAME [--ntasks N] [--launcher NAME]

Show the resolved scientific configuration, reusable-input state, and the
preparation/run plan without changing files.
USAGE
}

case_name=""
ntasks=""
launcher=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; case_name=$2; shift 2 ;;
    --case=*) case_name=${1#--case=}; shift ;;
    --ntasks) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; ntasks=$2; shift 2 ;;
    --ntasks=*) ntasks=${1#--ntasks=}; shift ;;
    --launcher) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; launcher=$2; shift 2 ;;
    --launcher=*) launcher=${1#--launcher=}; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'plan: unexpected argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$case_name" ]] || { usage >&2; exit 2; }
[[ "$case_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  printf 'plan: invalid case name: %s\n' "$case_name" >&2
  exit 2
}
[[ -z "$ntasks" || "$ntasks" =~ ^[1-9][0-9]*$ ]] || {
  printf 'plan: invalid --ntasks value: %s\n' "$ntasks" >&2
  exit 2
}
case "$launcher" in
  ""|auto|srun|mpirun|mpiexec|custom) ;;
  *) printf 'plan: invalid --launcher value: %s\n' "$launcher" >&2; exit 2 ;;
esac

case_dir="$WRFKIT_ROOT/cases/$case_name"
[[ -r "$case_dir/case.toml" ]] || {
  printf 'plan: case.toml not found: %s\n' "$case_dir/case.toml" >&2
  exit 2
}

"$WRFKIT_ROOT/scripts/case-config.py" summary --case "$case_name"
load_case_env "$case_name"

printf '\nReusable input state\n'
if [[ -d "$WRFKIT_GEOG_DIR" ]]; then
  printf '  geography:  cached (%s)\n' "$WRFKIT_GEOG_DIR"
else
  printf '  geography:  missing; prep will acquire it\n'
fi

if [[ "$FORCING_PROVIDER" == "gfs" ]]; then
  target_dir=$(gfs_target_dir)
  total=0
  cached=0
  for fh in $GFS_FORECAST_HOURS; do
    total=$((total + 1))
    file="$target_dir/gfs.t${GFS_CYCLE}z.pgrb2.0p25.f${fh}"
    [[ -s "$file" ]] && cached=$((cached + 1))
  done
  printf '  forcing:    %d/%d files cached (%s)\n' "$cached" "$total" "$target_dir"
else
  printf '  forcing:    provider %s (not supported by automatic prep yet)\n' "$FORCING_PROVIDER"
fi

printf '\nPreparation plan\n'
cat <<'PLAN'
  1. ensure static geography
  2. run geogrid
  3. ensure forcing data
  4. stage forcing / Vtable
  5. run ungrib
  6. run metgrid
  7. stage WRF runtime data
  8. run real -> wrfinput_d0* + wrfbdy_d01

Run plan
  9. wrfctl run -> wrf.exe -> wrfout_d0*
PLAN

if [[ -n "$ntasks" || -n "$launcher" ]]; then
  printf '\nRequested execution overrides\n'
  [[ -n "$ntasks" ]] && printf '  MPI tasks:   %s\n' "$ntasks"
  [[ -n "$launcher" ]] && printf '  launcher:    %s\n' "$launcher"
fi

printf '\nNo files were changed.\n'
