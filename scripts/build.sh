#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

usage() {
  cat <<'USAGE'
Usage: ./wrfctl build [wrf|wps|all] [--jobs N]

Default target: wrf

Targets:
  wrf   Build WRF 4.8.0.
  wps   Build WPS 4.7.0 against the existing WRF install.
  all   Build WRF first, then WPS.
USAGE
}

target=wrf
case "${1:-}" in
  wrf|wps|all) target=$1; shift ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  -*) ;;
  *) printf 'build: unknown target: %s\n' "$1" >&2; usage >&2; exit 2 ;;
esac

case "$target" in
  wrf) exec "$SCRIPT_DIR/build-wrf.sh" "$@" ;;
  wps) exec "$SCRIPT_DIR/build-wps.sh" "$@" ;;
  all)
    "$SCRIPT_DIR/build-wrf.sh" "$@"
    "$SCRIPT_DIR/build-wps.sh" "$@"
    ;;
esac
