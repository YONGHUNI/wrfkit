#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

usage() {
  cat <<'USAGE'
Usage: ./wrfctl fetch <wrf|wps|geog|gfs|all> [options]
USAGE
}

[[ $# -gt 0 ]] || {
  usage >&2
  exit 2
}

target=$1
shift

case "$target" in
  wrf) [[ $# -eq 0 ]] || { printf 'fetch wrf: unexpected argument: %s\n' "$1" >&2; exit 2; }; exec "$SCRIPT_DIR/fetch-wrf.sh" ;;
  wps) [[ $# -eq 0 ]] || { printf 'fetch wps: unexpected argument: %s\n' "$1" >&2; exit 2; }; exec "$SCRIPT_DIR/fetch-wps.sh" ;;
  geog) exec "$SCRIPT_DIR/fetch-geog.sh" "$@" ;;
  gfs) exec "$SCRIPT_DIR/fetch-gfs.sh" "$@" ;;
  all)
    [[ $# -eq 0 ]] || { printf 'fetch all: unexpected argument: %s\n' "$1" >&2; exit 2; }
    "$SCRIPT_DIR/fetch-wrf.sh"
    "$SCRIPT_DIR/fetch-wps.sh"
    ;;
  -h|--help)
    usage
    ;;
  *)
    printf 'fetch: unknown target: %s\n' "$target" >&2
    usage >&2
    exit 2
    ;;
esac
