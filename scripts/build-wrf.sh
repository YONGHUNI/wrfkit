#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

jobs=${WRFKIT_BUILD_JOBS:-${SLURM_CPUS_PER_TASK:-}}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs|-j) jobs=$2; shift 2 ;;
    -h|--help)
      echo "Usage: ./wrfctl build wrf [--jobs N]"
      exit 0
      ;;
    *) ui_error "build wrf: unknown option: $1"; exit 2 ;;
  esac
done

if [[ -z "$jobs" ]]; then
  jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '4')
fi
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || {
  ui_error "build wrf: invalid job count: $jobs"
  exit 2
}

ensure_wrf_source
rm -rf "$WRFKIT_BUILD_DIR" "$WRFKIT_INSTALL_DIR"
mkdir -p "$WRFKIT_BUILD_DIR" "$WRFKIT_INSTALL_DIR"

ui_heading "WRF build configuration"
ui_kv "version" "$WRFKIT_WRF_VERSION"
ui_kv "core" "ARW"
ui_kv "case" "EM_REAL"
ui_kv "MPI" "enabled"
ui_kv "source" "$WRFKIT_SRC_DIR"
ui_kv "build" "$WRFKIT_BUILD_DIR"
ui_kv "install" "$WRFKIT_INSTALL_DIR"
ui_kv "jobs" "$jobs"
printf '\n'

cd "$WRFKIT_SRC_DIR"

./configure_new \
  -p GNU \
  -x \
  -d "$WRFKIT_BUILD_DIR" \
  -i "$WRFKIT_INSTALL_DIR" \
  -- \
  -DWRF_CORE=ARW \
  -DWRF_NESTING=BASIC \
  -DWRF_CASE=EM_REAL \
  -DUSE_MPI=ON \
  -DUSE_OPENMP=OFF \
  -DUSE_PNETCDF=OFF \
  -DUSE_JASPER=OFF

./compile_new "$WRFKIT_BUILD_DIR" -j "$jobs"

for executable in real wrf; do
  path="$WRFKIT_INSTALL_DIR/bin/$executable"
  [[ -x "$path" ]] || {
    ui_error "Expected executable was not produced: $path"
    exit 1
  }
done

printf '\n'
ui_ok "WRF build completed."
ui_kv "real" "$WRFKIT_INSTALL_DIR/bin/real"
ui_kv "wrf" "$WRFKIT_INSTALL_DIR/bin/wrf"
printf '\n'
ui_warn "Multi-node MPI portability is not yet claimed by this MVP."
