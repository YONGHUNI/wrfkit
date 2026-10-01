#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

usage() { echo "Usage: ./wrfctl prepare wrf --case NAME" >&2; }

case_name=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      case_name=$2
      shift 2
      ;;
    --case=*)
      case_name=${1#--case=}
      shift
      ;;
    *)
      printf 'prepare wrf: unexpected argument: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ -n "$case_name" ]] || { usage; exit 2; }
[[ "$case_name" =~ ^[A-Za-z0-9._-]+$ ]] || {
  printf 'prepare wrf: invalid case name: %s\n' "$case_name" >&2
  exit 2
}

case_dir="$WRFKIT_ROOT/cases/$case_name"
[[ -d "$case_dir" ]] || {
  printf 'prepare wrf: case not found: %s\n' "$case_dir" >&2
  exit 2
}

wrf_run_dir="$WRFKIT_SRC_DIR/run"
[[ -d "$wrf_run_dir" ]] || {
  printf 'prepare wrf: WRF runtime directory not found: %s\n' "$wrf_run_dir" >&2
  printf 'Run ./wrfctl fetch wrf or ./wrfctl build wrf first.\n' >&2
  exit 2
}

[[ -r "$case_dir/namelist.input" ]] || {
  printf 'prepare wrf: namelist.input not found: %s\n' "$case_dir/namelist.input" >&2
  exit 2
}

linked=0
for src in "$wrf_run_dir"/*; do
  [[ -f "$src" ]] || continue
  name=$(basename "$src")

  # Scientific configuration remains case-owned. Runtime tables/data are
  # supplied by the pinned WRF source tree.
  [[ "$name" == "namelist.input" ]] && continue

  dest="$case_dir/$name"
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    printf 'prepare wrf: refusing to replace case-owned file: %s\n' "$dest" >&2
    exit 2
  fi

  rm -f "$dest"
  ln -s "../../.wrfkit/src/WRF-${WRFKIT_WRF_VERSION}/run/$name" "$dest"
  linked=$((linked + 1))
done

printf 'Prepared WRF runtime data for case %s:\n' "$case_name"
printf '  source: %s\n' "$wrf_run_dir"
printf '  linked runtime files: %d\n' "$linked"
