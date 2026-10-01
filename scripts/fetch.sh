#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

usage() {
  cat <<'USAGE'
Usage: ./wrfctl fetch <wrf|wps|geog|all>
USAGE
}

[[ $# -gt 0 ]] || {
  usage >&2
  exit 2
}

target=$1
shift

[[ $# -eq 0 ]] || {
  printf 'fetch: unexpected argument: %s\n' "$1" >&2
  exit 2
}

case "$target" in
  wrf) exec "$SCRIPT_DIR/fetch-wrf.sh" ;;
  wps) exec "$SCRIPT_DIR/fetch-wps.sh" ;;
  geog) exec "$SCRIPT_DIR/fetch-geog.sh" ;;
  all)
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
