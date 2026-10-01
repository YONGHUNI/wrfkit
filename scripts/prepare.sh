#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
usage() { echo "Usage: ./wrfctl prepare <gfs|wrf> --case NAME"; }
[[ $# -gt 0 ]] || { usage >&2; exit 2; }
target=$1
shift
case "$target" in
  gfs) exec "$SCRIPT_DIR/prepare-gfs.sh" "$@" ;;
  wrf) exec "$SCRIPT_DIR/prepare-wrf.sh" "$@" ;;
  -h|--help) usage ;;
  *) printf 'prepare: unknown target: %s\n' "$target" >&2; usage >&2; exit 2 ;;
esac
