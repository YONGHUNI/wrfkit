#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

jobs=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs|-j)
      requested_jobs=$2
      [[ "$requested_jobs" =~ ^[1-9][0-9]*$ ]] || {
        ui_error "build wps: invalid job count: $requested_jobs"
        exit 2
      }
      if [[ "$requested_jobs" != "1" ]]; then
        ui_error "WPS ${WRFKIT_WPS_VERSION} is built serially by wrfkit."
        cat >&2 <<'MSG'

Parallel WPS builds can race while multiple targets write shared Fortran
module files (for example ungrib filelist.mod/gridinfo.mod).

Use:
  ./wrfctl build wps
MSG
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./wrfctl build wps"
      echo "WPS is built serially to avoid upstream Fortran module-file races."
      exit 0
      ;;
    *) ui_error "build wps: unknown option: $1"; exit 2 ;;
  esac
done

wrf_config="$WRFKIT_INSTALL_DIR/lib/cmake/WRF/WRFConfig.cmake"
[[ -r "$wrf_config" ]] || {
  ui_error "WPS requires the CMake-built WRF install at $WRFKIT_INSTALL_DIR"
  printf 'Run ./wrfctl build wrf first, or ./wrfctl build all.\n' >&2
  exit 2
}

# WPS' bundled GRIB2 libraries are configured/built in-place. Start each WPS
# build from a pristine copy of the pinned source so rebuilds are deterministic.
reset_wps_source
rm -rf "$WRFKIT_WPS_BUILD_DIR" "$WRFKIT_WPS_INSTALL_DIR"
mkdir -p "$WRFKIT_WPS_BUILD_DIR" "$WRFKIT_WPS_INSTALL_DIR"

ui_heading "WPS build configuration"
ui_kv "version" "$WRFKIT_WPS_VERSION"
ui_kv "revision" "$WRFKIT_WPS_REV"
ui_kv "MPI" "enabled"
ui_kv "GRIB2" "bundled externals"
ui_kv "WRF root" "$WRFKIT_INSTALL_DIR"
ui_kv "source" "$WRFKIT_WPS_SRC_DIR"
ui_kv "build" "$WRFKIT_WPS_BUILD_DIR"
ui_kv "install" "$WRFKIT_WPS_INSTALL_DIR"
ui_kv "jobs" "$jobs (serial)"
printf '\n'

cd "$WRFKIT_WPS_SRC_DIR"

# WPS 4.7.0 builds its bundled Jasper/libpng/zlib under the install prefix
# during CMake configure, but the internal g2 target does not propagate the
# Jasper/libpng include directories to dec_jpeg2000.c/dec_png.c. Add the
# bundled include root explicitly so the GRIB2 decoder sources compile.
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
  -DBUILD_EXTERNALS=ON \
  -DCMAKE_C_FLAGS="-I$WRFKIT_WPS_INSTALL_DIR/grib2/include"

./compile_new "$WRFKIT_WPS_BUILD_DIR" -j "$jobs"

for executable in geogrid ungrib metgrid; do
  path="$WRFKIT_WPS_INSTALL_DIR/bin/$executable"
  [[ -x "$path" ]] || {
    ui_error "Expected WPS executable was not produced: $path"
    exit 1
  }
done

printf '\n'
ui_ok "WPS build completed."
ui_kv "geogrid" "$WRFKIT_WPS_INSTALL_DIR/bin/geogrid"
ui_kv "ungrib" "$WRFKIT_WPS_INSTALL_DIR/bin/ungrib"
ui_kv "metgrid" "$WRFKIT_WPS_INSTALL_DIR/bin/metgrid"
printf '\n'
ui_info "Build completion does not by itself validate the real-data preparation workflow."
