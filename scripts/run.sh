#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: ./wrfctl run --case NAME [--ntasks N] [--launcher NAME]

Run wrf.exe from a case prepared by wrfctl prep. Managed case.toml values are
rendered before launch. If case.toml or a native namelist changed after prep,
wrfkit prints a warning and continues with the existing wrfinput/wrfbdy.
Missing prep state or WRF/WPS version drift remains a hard error.
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
    *) ui_error "run: unexpected argument: $1"; usage >&2; exit 2 ;;
  esac
done

[[ -n "$case_name" ]] || { usage >&2; exit 2; }
[[ "$case_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  ui_error "run: invalid case name: $case_name"
  exit 2
}
[[ -z "$ntasks" || "$ntasks" =~ ^[1-9][0-9]*$ ]] || {
  ui_error "run: invalid --ntasks value: $ntasks"
  exit 2
}
case "$launcher" in
  ""|auto|srun|mpirun|mpiexec|custom) ;;
  *) ui_error "run: invalid --launcher value: $launcher"; exit 2 ;;
esac

case_dir="$WRFKIT_ROOT/cases/$case_name"
work_dir="$WRFKIT_WORK_DIR/$case_name"
[[ -r "$case_dir/case.toml" ]] || {
  ui_error "run: case.toml not found: $case_dir/case.toml"
  exit 2
}

# Apply managed case.toml values so changes made after prep are actually what
# wrf.exe receives. The manifest check below reports that prepared inputs predate
# those changes but deliberately leaves the reuse decision to the researcher.
"$WRFKIT_ROOT/wrfctl" config --case "$case_name"
printf '\n'
"$WRFKIT_ROOT/scripts/case-config.py" summary --case "$case_name"
verify_prep_manifest "$case_name"
if ((WRFKIT_PREP_CHANGED)); then
  ui_warn "Prepared inputs predate the current configuration; proceeding by user policy."
else
  ui_ok "Prepared inputs match the current case configuration."
fi
load_case_env "$case_name"

for ((domain_id=1; domain_id<=MAX_DOM; domain_id++)); do
  printf -v domain "%02d" "$domain_id"
  [[ -s "$work_dir/wrfinput_d$domain" ]] || {
    ui_error "Missing prepared input: $work_dir/wrfinput_d$domain"
    printf 'Run ./wrfctl prep --case %s first.\n' "$case_name" >&2
    exit 2
  }
done
[[ -s "$work_dir/wrfbdy_d01" ]] || {
  ui_error "Missing prepared boundary file: $work_dir/wrfbdy_d01"
  printf 'Run ./wrfctl prep --case %s first.\n' "$case_name" >&2
  exit 2
}

default_tasks=$("$WRFKIT_ROOT/wrfctl" __resolve-mpi-tasks)
effective_tasks=${ntasks:-$default_tasks}
eval "$("$WRFKIT_ROOT/scripts/case-config.py" mpi-plan --case "$case_name" --requested "$effective_tasks" --shell)"

if [[ -n "$ntasks" && "$WRFKIT_WRF_TASKS" != "$ntasks" ]]; then
  ui_error "Explicit --ntasks=$ntasks is unsafe for this WRF domain."
  printf 'WRF-safe choice at or below that request: %s tasks (%s x %s).\n' \
    "$WRFKIT_WRF_TASKS" "$WRFKIT_NPROC_X" "$WRFKIT_NPROC_Y" >&2
  exit 2
fi

exec_case_args=(--case "$case_name" --ntasks "$WRFKIT_WRF_TASKS")
[[ -n "$launcher" ]] && exec_case_args+=(--launcher "$launcher")

# The persistent log archive keeps previous diagnostics; clear fixed-name RSL
# files in the workspace so post-run checks cannot accept stale WRF output.
rm -f "$work_dir"/rsl.out.* "$work_dir"/rsl.error.*

marker="$work_dir/.wrfkit-run-started"
: > "$marker"
trap 'rm -f "$marker"' EXIT

printf '\n'
ui_heading "wrfkit run"
ui_kv "case" "$case_name"
ui_kv "workspace" "$work_dir"
ui_kv "WRF tasks" "$WRFKIT_WRF_TASKS ($WRFKIT_NPROC_X x $WRFKIT_NPROC_Y)"
if ((WRFKIT_TASKS_ADJUSTED)); then
  ui_warn "WRF tasks auto-adjusted $effective_tasks -> $WRFKIT_WRF_TASKS for >=10-cell patches."
fi
printf '\n'

"$WRFKIT_ROOT/wrfctl" exec wrf "${exec_case_args[@]}"

[[ -f "$work_dir/rsl.out.0000" && "$work_dir/rsl.out.0000" -nt "$marker" ]] || {
  ui_error "Current WRF run did not produce rsl.out.0000"
  exit 1
}
grep -q "SUCCESS COMPLETE WRF" "$work_dir/rsl.out.0000" || {
  ui_error "wrf.exe returned but SUCCESS COMPLETE WRF was not found in current rsl.out.0000"
  exit 1
}

new_output=$(find "$work_dir" -maxdepth 1 -type f -name 'wrfout_d01_*' -newer "$marker" -print -quit)
[[ -n "$new_output" ]] || {
  ui_error "WRF completed but no new wrfout_d01_* file was detected"
  exit 1
}

rm -f "$marker"
trap - EXIT

printf '\n'
ui_ok "WRF completed for case $case_name: SUCCESS COMPLETE WRF"
ui_kv "output" "$new_output"
