#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: ./wrfctl prep --case NAME [--ntasks N] [--launcher NAME] [--dry-run]

Prepare one case until it is ready for wrf.exe:
  geography -> geogrid -> forcing -> ungrib -> metgrid -> WRF staging -> real

--dry-run shows the resolved scientific configuration and plan without changes.
The lower-level fetch/prepare/exec commands remain available for debugging.
USAGE
}

case_name=""
ntasks=""
launcher=""
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      case_name=$2
      shift 2
      ;;
    --case=*)
      case_name=${1#--case=}
      shift
      ;;
    --ntasks)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      ntasks=$2
      shift 2
      ;;
    --ntasks=*)
      ntasks=${1#--ntasks=}
      shift
      ;;
    --launcher)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      launcher=$2
      shift 2
      ;;
    --launcher=*)
      launcher=${1#--launcher=}
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'prep: unexpected argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n "$case_name" ]] || { usage >&2; exit 2; }
[[ "$case_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  printf 'prep: invalid case name: %s\n' "$case_name" >&2
  exit 2
}
[[ -z "$ntasks" || "$ntasks" =~ ^[1-9][0-9]*$ ]] || {
  printf 'prep: invalid --ntasks value: %s\n' "$ntasks" >&2
  exit 2
}

case "$launcher" in
  ""|auto|srun|mpirun|mpiexec|custom) ;;
  *) printf 'prep: invalid --launcher value: %s\n' "$launcher" >&2; exit 2 ;;
esac

if ((dry_run)); then
  plan_args=(--case "$case_name")
  [[ -n "$ntasks" ]] && plan_args+=(--ntasks "$ntasks")
  [[ -n "$launcher" ]] && plan_args+=(--launcher "$launcher")
  "$WRFKIT_ROOT/wrfctl" plan "${plan_args[@]}"
  exit $?
fi

case_dir="$WRFKIT_ROOT/cases/$case_name"
[[ -d "$case_dir" ]] || {
  printf 'prep: case not found: %s\n' "$case_dir" >&2
  exit 2
}
[[ -r "$case_dir/case.toml" ]] || {
  printf 'prep: case config not found: %s\n' "$case_dir/case.toml" >&2
  exit 2
}

# Render TOML-managed namelist values before any native WPS/WRF stage runs.
"$WRFKIT_ROOT/wrfctl" config --case "$case_name"
load_case_env "$case_name"

printf '\n'
"$WRFKIT_ROOT/scripts/case-config.py" summary --case "$case_name"

if [[ "$GEOG_DATASET" != "wps-lowres-mandatory" || "$GEOG_RESOLUTION" != "lowres" ]]; then
  cat >&2 <<MSG
prep: automatic geography acquisition currently supports only:
  dataset = "wps-lowres-mandatory"
  resolution = "lowres"

Case: $case_name
Requested: dataset=$GEOG_DATASET resolution=$GEOG_RESOLUTION
Use the lower-level geography workflow until research-grade geography selection
is implemented.
MSG
  exit 2
fi

forcing_provider=${FORCING_PROVIDER:-gfs}
case "$forcing_provider" in
  gfs) ;;
  *)
    printf 'prep: unsupported forcing provider: %s\n' "$forcing_provider" >&2
    exit 2
    ;;
esac

exec_case_args=(--case "$case_name")
[[ -n "$ntasks" ]] && exec_case_args+=(--ntasks "$ntasks")
[[ -n "$launcher" ]] && exec_case_args+=(--launcher "$launcher")

step() {
  printf '\n==> %s\n' "$1"
}

printf 'wrfkit prep\n'
printf '  case:       %s\n' "$case_name"
printf '  forcing:    %s\n' "$forcing_provider"
printf '  data root:  %s\n' "$WRFKIT_DATA_DIR"
printf '  workspace:  %s/work/%s\n' "$WRFKIT_STATE_DIR" "$case_name"

step "1/8 Ensure static geography"
"$WRFKIT_ROOT/wrfctl" fetch geog

step "2/8 Run geogrid"
"$WRFKIT_ROOT/wrfctl" exec geogrid "${exec_case_args[@]}"

step "3/8 Ensure forcing data"
"$WRFKIT_ROOT/wrfctl" fetch "$forcing_provider" --case "$case_name"

step "4/8 Stage forcing for WPS"
"$WRFKIT_ROOT/wrfctl" prepare "$forcing_provider" --case "$case_name"

step "5/8 Run ungrib"
"$WRFKIT_ROOT/wrfctl" exec ungrib --case "$case_name"

step "6/8 Run metgrid"
"$WRFKIT_ROOT/wrfctl" exec metgrid "${exec_case_args[@]}"

step "7/8 Stage WRF runtime data"
"$WRFKIT_ROOT/wrfctl" prepare wrf --case "$case_name"

step "8/8 Run real"
work_dir="$WRFKIT_WORK_DIR/$case_name"
rm -f "$work_dir"/wrfinput_d?? "$work_dir"/wrfbdy_d01
"$WRFKIT_ROOT/wrfctl" exec real "${exec_case_args[@]}"

for ((domain_id=1; domain_id<=MAX_DOM; domain_id++)); do
  printf -v domain "%02d" "$domain_id"
  [[ -s "$work_dir/wrfinput_d$domain" ]] || {
    printf 'prep: real completed but wrfinput_d%s is missing or empty\n' "$domain" >&2
    exit 1
  }
done
[[ -s "$work_dir/wrfbdy_d01" ]] || {
  printf 'prep: real completed but wrfbdy_d01 is missing or empty\n' >&2
  exit 1
}

write_prep_manifest "$case_name"

printf '\nwrfkit prep completed for case %s.\n' "$case_name"
printf 'Prepared model inputs:\n'
printf '  %s/wrfinput_d0*\n' "$work_dir"
printf '  %s/wrfbdy_d01\n' "$work_dir"
printf 'Next:\n'
printf '  ./wrfctl run --case %s\n' "$case_name"
