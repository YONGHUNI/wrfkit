#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

usage() {
  cat <<'USAGE'
Usage: ./wrfctl fetch [wrf|wps|all]

Default target: wrf
USAGE
}

target=wrf
case "${1:-}" in
  wrf|wps|all) target=$1; shift ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  -*) printf 'fetch: unknown option: %s\n' "$1" >&2; exit 2 ;;
  *) printf 'fetch: unknown target: %s\n' "$1" >&2; usage >&2; exit 2 ;;
esac

[[ $# -eq 0 ]] || {
  printf 'fetch: unexpected argument: %s\n' "$1" >&2
  exit 2
}

case "$target" in
  wrf) exec "$SCRIPT_DIR/fetch-wrf.sh" ;;
  wps) exec "$SCRIPT_DIR/fetch-wps.sh" ;;
  all)
    "$SCRIPT_DIR/fetch-wrf.sh"
    "$SCRIPT_DIR/fetch-wps.sh"
    ;;
esac
