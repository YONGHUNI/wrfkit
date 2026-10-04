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
    *) ui_error "plan: unexpected argument: $1"; usage >&2; exit 2 ;;
  esac
done

[[ -n "$case_name" ]] || { usage >&2; exit 2; }
[[ "$case_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  ui_error "plan: invalid case name: $case_name"
  exit 2
}
[[ -z "$ntasks" || "$ntasks" =~ ^[1-9][0-9]*$ ]] || {
  ui_error "plan: invalid --ntasks value: $ntasks"
  exit 2
}
case "$launcher" in
  ""|auto|srun|mpirun|mpiexec|custom) ;;
  *) ui_error "plan: invalid --launcher value: $launcher"; exit 2 ;;
esac

case_dir="$WRFKIT_ROOT/cases/$case_name"
[[ -r "$case_dir/case.toml" ]] || {
  ui_error "plan: case.toml not found: $case_dir/case.toml"
  exit 2
}

"$WRFKIT_ROOT/scripts/case-config.py" summary --case "$case_name"
load_case_env "$case_name"

default_tasks=$("$WRFKIT_ROOT/wrfctl" __resolve-mpi-tasks)
effective_tasks=${ntasks:-$default_tasks}
effective_launcher=${launcher:-$("$WRFKIT_ROOT/wrfctl" __resolve-mpi-launcher)}
eval "$("$WRFKIT_ROOT/scripts/case-config.py" mpi-plan --case "$case_name" --requested "$effective_tasks" --shell)"

printf '\n'
ui_heading "Execution plan"
ui_kv "launcher" "$effective_launcher"
ui_kv "WPS MPI" "$effective_tasks tasks"
ui_kv "real / WRF" "$WRFKIT_WRF_TASKS tasks ($WRFKIT_NPROC_X x $WRFKIT_NPROC_Y decomposition)"
if ((WRFKIT_TASKS_ADJUSTED)); then
  ui_warn "WRF tasks auto-adjusted $effective_tasks -> $WRFKIT_WRF_TASKS to keep patches >= 10 cells."
fi
if [[ -n "$ntasks" && "$WRFKIT_WRF_TASKS" != "$ntasks" ]]; then
  ui_warn "Explicit --ntasks=$ntasks is unsafe for real/wrf; prep/run will reject it."
fi

printf '\n'
ui_heading "Reusable input state"
if [[ -d "$WRFKIT_GEOG_DIR" ]]; then
  ui_ok "Geography cached: $WRFKIT_GEOG_DIR"
else
  ui_info "Geography missing; prep will acquire it."
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
  if ((cached == total)); then
    ui_ok "Forcing cached: $cached/$total files ($target_dir)"
  else
    ui_info "Forcing cached: $cached/$total files ($target_dir)"
  fi
else
  ui_warn "Forcing provider $FORCING_PROVIDER is not supported by automatic prep yet."
fi

printf '\n'
ui_heading "Preparation plan"

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
  printf '\n'
  ui_heading "Requested execution overrides"
  [[ -n "$ntasks" ]] && printf '  MPI tasks:   %s\n' "$ntasks"
  [[ -n "$launcher" ]] && printf '  launcher:    %s\n' "$launcher"
fi

printf '\n'
ui_ok "Read-only plan; no files were changed."

