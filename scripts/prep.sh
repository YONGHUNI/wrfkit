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
      ui_error "prep: unexpected argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n "$case_name" ]] || { usage >&2; exit 2; }
[[ "$case_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  ui_error "prep: invalid case name: $case_name"
  exit 2
}
[[ -z "$ntasks" || "$ntasks" =~ ^[1-9][0-9]*$ ]] || {
  ui_error "prep: invalid --ntasks value: $ntasks"
  exit 2
}

case "$launcher" in
  ""|auto|srun|mpirun|mpiexec|custom) ;;
  *) ui_error "prep: invalid --launcher value: $launcher"; exit 2 ;;
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
  ui_error "prep: case not found: $case_dir"
  exit 2
}
[[ -r "$case_dir/case.toml" ]] || {
  ui_error "prep: case config not found: $case_dir/case.toml"
  exit 2
}

# Render TOML-managed namelist values before any native WPS/WRF stage runs.
"$WRFKIT_ROOT/wrfctl" config --case "$case_name"
load_case_env "$case_name"

printf '\n'
"$WRFKIT_ROOT/scripts/case-config.py" summary --case "$case_name"

forcing_provider=${FORCING_PROVIDER:-gfs}
case "$forcing_provider" in
  gfs) ;;
  *)
    ui_error "prep: unsupported forcing provider: $forcing_provider"
    exit 2
    ;;
esac

default_tasks=$("$WRFKIT_ROOT/wrfctl" __resolve-mpi-tasks)
effective_tasks=${ntasks:-$default_tasks}
eval "$("$WRFKIT_ROOT/scripts/case-config.py" mpi-plan --case "$case_name" --requested "$effective_tasks" --shell)"

if [[ -n "$ntasks" && "$WRFKIT_WRF_TASKS" != "$ntasks" ]]; then
  ui_error "Explicit --ntasks=$ntasks is unsafe for this WRF domain."
  printf 'WRF-safe choice at or below that request: %s tasks (%s x %s).\n' \
    "$WRFKIT_WRF_TASKS" "$WRFKIT_NPROC_X" "$WRFKIT_NPROC_Y" >&2
  printf 'Omit --ntasks to allow stage-safe auto selection, or request a safe count.\n' >&2
  exit 2
fi

wps_exec_args=(--case "$case_name")
[[ -n "$ntasks" ]] && wps_exec_args+=(--ntasks "$ntasks")
[[ -n "$launcher" ]] && wps_exec_args+=(--launcher "$launcher")

wrf_exec_args=(--case "$case_name" --ntasks "$WRFKIT_WRF_TASKS")
[[ -n "$launcher" ]] && wrf_exec_args+=(--launcher "$launcher")

step() {
  ui_step "$1"
}

ui_heading "wrfkit prep"
ui_kv "case" "$case_name"
ui_kv "forcing" "$forcing_provider"
ui_kv "geography" "$GEOG_DATASET ($GEOG_RESOLUTION)"
ui_kv "geog path" "$WRFKIT_GEOG_DIR"
ui_kv "data root" "$WRFKIT_DATA_DIR"
ui_kv "workspace" "$WRFKIT_STATE_DIR/work/$case_name"
ui_kv "WPS tasks" "$effective_tasks"
ui_kv "WRF tasks" "$WRFKIT_WRF_TASKS ($WRFKIT_NPROC_X x $WRFKIT_NPROC_Y)"
if ((WRFKIT_TASKS_ADJUSTED)); then
  ui_warn "WRF tasks auto-adjusted $effective_tasks -> $WRFKIT_WRF_TASKS for >=10-cell patches."
fi

step "1/8 Ensure static geography"
case "$GEOG_MANAGEMENT" in
  external)
    [[ -d "$WRFKIT_GEOG_DIR" ]] || {
      ui_error "External geography directory not found: $WRFKIT_GEOG_DIR"
      exit 2
    }
    ui_ok "Using user-provided geography: $WRFKIT_GEOG_DIR"
    ;;
  managed)
    if [[ "${GEOG_AUTO_ACQUIRE:-0}" == "1" ]]; then
      WRFKIT_GEOG_DIR="$WRFKIT_GEOG_DIR" "$WRFKIT_ROOT/wrfctl" fetch geog
    else
      ui_error "Automatic geography acquisition is not implemented for $GEOG_DATASET."
      printf 'Resolved target: %s\n' "$WRFKIT_GEOG_DIR" >&2
      printf 'Use dataset="external" with path=... for geography you provide yourself.\n' >&2
      exit 2
    fi
    ;;
  *)
    ui_error "Unknown geography management mode: $GEOG_MANAGEMENT"
    exit 2
    ;;
esac

step "2/8 Run geogrid"
"$WRFKIT_ROOT/wrfctl" exec geogrid "${wps_exec_args[@]}"

step "3/8 Ensure forcing data"
"$WRFKIT_ROOT/wrfctl" fetch "$forcing_provider" --case "$case_name"

step "4/8 Stage forcing for WPS"
"$WRFKIT_ROOT/wrfctl" prepare "$forcing_provider" --case "$case_name"

step "5/8 Run ungrib"
"$WRFKIT_ROOT/wrfctl" exec ungrib --case "$case_name"

step "6/8 Run metgrid"
"$WRFKIT_ROOT/wrfctl" exec metgrid "${wps_exec_args[@]}"

step "7/8 Stage WRF runtime data"
"$WRFKIT_ROOT/wrfctl" prepare wrf --case "$case_name"

step "8/8 Run real"
work_dir="$WRFKIT_WORK_DIR/$case_name"
rm -f "$work_dir"/wrfinput_d?? "$work_dir"/wrfbdy_d01
"$WRFKIT_ROOT/wrfctl" exec real "${wrf_exec_args[@]}"

for ((domain_id=1; domain_id<=MAX_DOM; domain_id++)); do
  printf -v domain "%02d" "$domain_id"
  [[ -s "$work_dir/wrfinput_d$domain" ]] || {
    ui_error "real.exe completed but wrfinput_d$domain is missing or empty"
    exit 1
  }
done
[[ -s "$work_dir/wrfbdy_d01" ]] || {
  ui_error "real.exe completed but wrfbdy_d01 is missing or empty"
  exit 1
}

write_prep_manifest "$case_name"

printf '\n'
ui_ok "Prep completed for case $case_name."
ui_heading "Prepared model inputs"
ui_kv "wrfinput" "$work_dir/wrfinput_d0*"
ui_kv "wrfbdy" "$work_dir/wrfbdy_d01"
printf '\n'
ui_heading "Next"
printf '  ./wrfctl run --case %s\n' "$case_name"
