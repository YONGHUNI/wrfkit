#!/usr/bin/env bash

if [[ -z ${WRFKIT_NIX_SHELL:-} ]]; then
  echo "wrfkit: helper must run inside the project Nix environment" >&2
  exit 2
fi

WRFKIT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
WRFKIT_STATE_DIR=${WRFKIT_STATE_DIR:-"$WRFKIT_ROOT/.wrfkit"}
WRFKIT_SRC_DIR=${WRFKIT_SRC_DIR:-"$WRFKIT_STATE_DIR/src/WRF-${WRFKIT_WRF_VERSION}"}

# WRF 4.8.0's configure_new currently runs 'cmake ..' after cd'ing into
# the selected build directory. Therefore the build directory must be a direct
# child of the WRF source tree; an arbitrary sibling/out-of-tree path fails.
WRFKIT_BUILD_DIR=${WRFKIT_BUILD_DIR:-"$WRFKIT_SRC_DIR/_build-wrfkit"}

WRFKIT_INSTALL_DIR=${WRFKIT_INSTALL_DIR:-"$WRFKIT_STATE_DIR/install/wrf-${WRFKIT_WRF_VERSION}"}

ensure_wrf_source() {
  [[ -x "$WRFKIT_SRC_DIR/configure_new" ]] && return 0

  [[ -r ${WRFKIT_WRF_ARCHIVE:-} ]] || {
    echo "wrfkit: pinned WRF archive is unavailable" >&2
    exit 2
  }

  rm -rf "$WRFKIT_SRC_DIR"
  mkdir -p "$WRFKIT_SRC_DIR"
  echo "Extracting WRF ${WRFKIT_WRF_VERSION} source..."
  tar -xzf "$WRFKIT_WRF_ARCHIVE" -C "$WRFKIT_SRC_DIR" --strip-components=1

  [[ -x "$WRFKIT_SRC_DIR/configure_new" ]] || {
    echo "wrfkit: extracted WRF source is missing configure_new" >&2
    exit 2
  }
}
