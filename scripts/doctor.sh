#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

status=0
ok()   { printf '[OK]   %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; status=1; }

check_cmd() {
  local cmd=$1
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd -> $(command -v "$cmd")"
  else
    fail "$cmd not found"
  fi
}

printf 'wrfkit doctor\n\nWRF version: %s\nSystem: %s\n\n'   "$WRFKIT_WRF_VERSION" "$(uname -srm)"

for cmd in gcc g++ gfortran cmake make mpicc mpif90 mpirun nc-config nf-config; do
  check_cmd "$cmd"
done

printf '\nVersions\n'
printf '  gcc:       %s\n' "$(gcc -dumpfullversion -dumpversion 2>/dev/null || true)"
printf '  gfortran:  %s\n' "$(gfortran -dumpfullversion -dumpversion 2>/dev/null || true)"
printf '  cmake:     %s\n' "$(cmake --version 2>/dev/null | head -n1 || true)"
printf '  MPI:       %s\n' "$(mpirun --version 2>/dev/null | head -n1 || true)"
printf '  netCDF-C:  %s\n' "$(nc-config --version 2>/dev/null || true)"
printf '  netCDF-F:  %s\n' "$(nf-config --version 2>/dev/null || true)"

printf '\nPinned WRF archive\n'
if [[ -r "$WRFKIT_WRF_ARCHIVE" ]]; then
  ok "$WRFKIT_WRF_ARCHIVE"
else
  fail "WRF archive is unavailable: $WRFKIT_WRF_ARCHIVE"
fi

exit "$status"
