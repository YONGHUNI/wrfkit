#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

usage() { echo "Usage: ./wrfctl prepare gfs --case NAME" >&2; }
case_name=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) [[ $# -ge 2 ]] || { usage; exit 2; }; case_name=$2; shift 2 ;;
    --case=*) case_name=${1#--case=}; shift ;;
    *) printf 'prepare gfs: unexpected argument: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$case_name" ]] || { usage; exit 2; }
case_dir="$WRFKIT_ROOT/cases/$case_name"
work_dir=$(stage_case_workspace "$case_name")
forcing_conf="$case_dir/forcing.conf"
[[ -r "$forcing_conf" ]] || { printf 'prepare gfs: forcing config not found: %s\n' "$forcing_conf" >&2; exit 2; }

# shellcheck disable=SC1090
source "$forcing_conf"

target_dir=$(gfs_target_dir)
vtable_src="$WRFKIT_WPS_SRC_DIR/ungrib/Variable_Tables/Vtable.GFS"
[[ -r "$vtable_src" ]] || {
  printf 'prepare gfs: Vtable.GFS not found: %s\n' "$vtable_src" >&2
  printf 'Run ./wrfctl fetch wps or ./wrfctl build wps first.\n' >&2
  exit 2
}

rm -f "$work_dir/Vtable"
ln -s "$vtable_src" "$work_dir/Vtable"
rm -f "$work_dir"/GRIBFILE.???

suffixes=(AAA AAB AAC AAD AAE AAF AAG AAH AAI AAJ AAK AAL AAM AAN AAO AAP)
i=0
for fh in $GFS_FORECAST_HOURS; do
  file="gfs.t${GFS_CYCLE}z.pgrb2.0p25.f${fh}"
  src="$target_dir/$file"
  [[ -s "$src" ]] || {
    printf 'prepare gfs: missing forcing file: %s\n' "$src" >&2
    printf 'Run ./wrfctl fetch gfs --case %s first.\n' "$case_name" >&2
    exit 2
  }
  (( i < ${#suffixes[@]} )) || { echo "prepare gfs: too many forcing files for current smoke-test linker" >&2; exit 2; }
  ln -s "$src" "$work_dir/GRIBFILE.${suffixes[$i]}"
  i=$((i + 1))
done

printf 'Prepared GFS forcing for case %s:\n' "$case_name"
printf '  workspace: %s\n' "$work_dir"
printf '  Vtable -> %s\n' "$(readlink "$work_dir/Vtable")"
printf '  GRIB files: %d\n' "$i"
