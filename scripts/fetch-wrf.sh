#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

ensure_wrf_source
printf 'WRF %s source: %s\n' "$WRFKIT_WRF_VERSION" "$WRFKIT_SRC_DIR"
