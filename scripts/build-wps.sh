#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

jobs=${WRFKIT_BUILD_JOBS:-${SLURM_CPUS_PER_TASK:-}}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs|-j) jobs=$2; shift 2 ;;
    -h|--help)
      echo "Usage: ./wrfctl build wps [--jobs N]"
      exit 0
      ;;
    *) printf 'build-wps: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

if [[ -z "$jobs" ]]; then
  jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '4')
fi
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || {
  printf 'build-wps: invalid job count: %s\n' "$jobs" >&2
  exit 2
}

wrf_config="$WRFKIT_INSTALL_DIR/lib/cmake/WRF/WRFConfig.cmake"
[[ -r "$wrf_config" ]] || {
  printf 'wrfkit: WPS requires the CMake-built WRF install at %s\n' "$WRFKIT_INSTALL_DIR" >&2
  printf 'Run ./wrfctl build wrf first, or ./wrfctl build all.\n' >&2
  exit 2
}

# WPS' bundled GRIB2 libraries are configured/built in-place. Start each WPS
# build from a pristine copy of the pinned source so rebuilds are deterministic.
reset_wps_source
rm -rf "$WRFKIT_WPS_BUILD_DIR" "$WRFKIT_WPS_INSTALL_DIR"
mkdir -p "$WRFKIT_WPS_BUILD_DIR" "$WRFKIT_WPS_INSTALL_DIR"

printf 'WPS build configuration\n'
printf '  version: %s\n  revision: %s\n  MPI: enabled\n  GRIB2: bundled externals\n' \
  "$WRFKIT_WPS_VERSION" "$WRFKIT_WPS_REV"
printf '  WRF root: %s\n  source: %s\n  build: %s\n  install: %s\n  jobs: %s\n\n' \
  "$WRFKIT_INSTALL_DIR" "$WRFKIT_WPS_SRC_DIR" "$WRFKIT_WPS_BUILD_DIR" \
  "$WRFKIT_WPS_INSTALL_DIR" "$jobs"

cd "$WRFKIT_WPS_SRC_DIR"

./configure_new \
  -p gfortran \
  -x \
  -d "$WRFKIT_WPS_BUILD_DIR" \
  -i "$WRFKIT_WPS_INSTALL_DIR" \
  -- \
  -DCMAKE_BUILD_TYPE=Release \
  -DWRF_ROOT="$WRFKIT_INSTALL_DIR" \
  -DUSE_WRF=ON \
  -DUSE_MPI=ON \
  -DUSE_OPENMP=OFF \
  -DBUILD_EXTERNALS=ON

./compile_new "$WRFKIT_WPS_BUILD_DIR" -j "$jobs"

for executable in geogrid ungrib metgrid; do
  path="$WRFKIT_WPS_INSTALL_DIR/bin/$executable"
  [[ -x "$path" ]] || {
    printf 'wrfkit: expected WPS executable was not produced: %s\n' "$path" >&2
    exit 1
  }
done

printf '\nWPS build completed.\n'
printf '  geogrid: %s/bin/geogrid\n' "$WRFKIT_WPS_INSTALL_DIR"
printf '  ungrib:  %s/bin/ungrib\n' "$WRFKIT_WPS_INSTALL_DIR"
printf '  metgrid: %s/bin/metgrid\n' "$WRFKIT_WPS_INSTALL_DIR"
printf '\nWPS data acquisition and real-data prepare workflow are not yet claimed by this build step.\n'
