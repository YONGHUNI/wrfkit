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
    *) printf 'build-wrf: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [[ -z "$jobs" ]]; then
  jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '4')
fi
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || {
  printf 'build-wrf: invalid job count: %s\n' "$jobs" >&2
  exit 2
}

ensure_wrf_source
rm -rf "$WRFKIT_BUILD_DIR" "$WRFKIT_INSTALL_DIR"
mkdir -p "$WRFKIT_BUILD_DIR" "$WRFKIT_INSTALL_DIR"

printf 'WRF build configuration\n'
printf '  version: %s\n  core: ARW\n  case: EM_REAL\n  MPI: enabled\n' "$WRFKIT_WRF_VERSION"
printf '  source: %s\n  build: %s\n  install: %s\n  jobs: %s\n\n' \
  "$WRFKIT_SRC_DIR" "$WRFKIT_BUILD_DIR" "$WRFKIT_INSTALL_DIR" "$jobs"

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
    printf 'wrfkit: expected executable was not produced: %s\n' "$path" >&2
    exit 1
  }
done

printf '\nWRF build completed.\n  real: %s/bin/real\n  wrf:  %s/bin/wrf\n' \
  "$WRFKIT_INSTALL_DIR" "$WRFKIT_INSTALL_DIR"
printf '\nMulti-node MPI portability is not yet claimed by this MVP.\n'
