#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

usage() {
  cat <<'USAGE'
Usage: ./wrfctl build <wrf|wps|all> [--jobs N]

Targets:
  wrf   Build WRF 4.8.0. --jobs N controls WRF parallelism.
  wps   Build WPS 4.7.0 serially against the existing WRF install.
  all   Build WRF first, then build WPS serially. --jobs N applies to WRF.
USAGE
}

[[ $# -gt 0 ]] || {
  usage >&2
  exit 2
}

target=$1
shift

case "$target" in
  wrf) exec "$SCRIPT_DIR/build-wrf.sh" "$@" ;;
  wps) exec "$SCRIPT_DIR/build-wps.sh" "$@" ;;
  all)
    "$SCRIPT_DIR/build-wrf.sh" "$@"
    "$SCRIPT_DIR/build-wps.sh"
    ;;
  -h|--help)
    usage
    ;;
  *)
    printf 'build: unknown target: %s\n' "$target" >&2
    usage >&2
    exit 2
    ;;
esac
