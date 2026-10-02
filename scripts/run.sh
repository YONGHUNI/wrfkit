#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: ./wrfctl run --case NAME [--ntasks N] [--launcher NAME]

Run wrf.exe from a case prepared by wrfctl prep. The command refuses to use
prepared inputs when case.toml or the native namelists changed after prep.
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
    *) printf 'run: unexpected argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$case_name" ]] || { usage >&2; exit 2; }
[[ "$case_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  printf 'run: invalid case name: %s\n' "$case_name" >&2
  exit 2
}
[[ -z "$ntasks" || "$ntasks" =~ ^[1-9][0-9]*$ ]] || {
  printf 'run: invalid --ntasks value: %s\n' "$ntasks" >&2
  exit 2
}
case "$launcher" in
  ""|auto|srun|mpirun|mpiexec|custom) ;;
  *) printf 'run: invalid --launcher value: %s\n' "$launcher" >&2; exit 2 ;;
esac

case_dir="$WRFKIT_ROOT/cases/$case_name"
work_dir="$WRFKIT_WORK_DIR/$case_name"
[[ -r "$case_dir/case.toml" ]] || {
  printf 'run: case.toml not found: %s\n' "$case_dir/case.toml" >&2
  exit 2
}

"$WRFKIT_ROOT/scripts/case-config.py" summary --case "$case_name"
verify_prep_manifest "$case_name"
load_case_env "$case_name"

for ((domain_id=1; domain_id<=MAX_DOM; domain_id++)); do
  printf -v domain "%02d" "$domain_id"
  [[ -s "$work_dir/wrfinput_d$domain" ]] || {
    printf 'run: missing prepared input: %s/wrfinput_d%s\n' "$work_dir" "$domain" >&2
    printf 'Run ./wrfctl prep --case %s first.\n' "$case_name" >&2
    exit 2
  }
done
[[ -s "$work_dir/wrfbdy_d01" ]] || {
  printf 'run: missing prepared boundary file: %s/wrfbdy_d01\n' "$work_dir" >&2
  printf 'Run ./wrfctl prep --case %s first.\n' "$case_name" >&2
  exit 2
}

exec_case_args=(--case "$case_name")
[[ -n "$ntasks" ]] && exec_case_args+=(--ntasks "$ntasks")
[[ -n "$launcher" ]] && exec_case_args+=(--launcher "$launcher")

marker="$work_dir/.wrfkit-run-started"
: > "$marker"
trap 'rm -f "$marker"' EXIT

printf '\nwrfkit run\n'
printf '  case:       %s\n' "$case_name"
printf '  workspace:  %s\n\n' "$work_dir"

"$WRFKIT_ROOT/wrfctl" exec wrf "${exec_case_args[@]}"

[[ -f "$work_dir/rsl.out.0000" && "$work_dir/rsl.out.0000" -nt "$marker" ]] || {
  printf 'run: current WRF run did not produce rsl.out.0000\n' >&2
  exit 1
}
grep -q "SUCCESS COMPLETE WRF" "$work_dir/rsl.out.0000" || {
  printf 'run: wrf.exe returned but SUCCESS COMPLETE WRF was not found in current rsl.out.0000\n' >&2
  exit 1
}

new_output=$(find "$work_dir" -maxdepth 1 -type f -name 'wrfout_d01_*' -newer "$marker" -print -quit)
[[ -n "$new_output" ]] || {
  printf 'run: WRF completed but no new wrfout_d01_* file was detected\n' >&2
  exit 1
}

rm -f "$marker"
trap - EXIT

printf '\nwrfkit run completed for case %s.\n' "$case_name"
printf '  success: SUCCESS COMPLETE WRF\n'
printf '  output:  %s\n' "$new_output"
