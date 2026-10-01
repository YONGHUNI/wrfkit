#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

ensure_wps_source
printf 'WPS %s source: %s\n' "$WRFKIT_WPS_VERSION" "$WRFKIT_WPS_SRC_DIR"
printf 'WPS revision: %s\n' "$WRFKIT_WPS_REV"
