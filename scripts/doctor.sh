#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

status=0
ok()   { ui_ok "$*"; }
fail() { ui_fail "$*"; status=1; }

check_cmd() {
  local cmd=$1
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd -> $(command -v "$cmd")"
  else
    fail "$cmd not found"
  fi
}

ui_heading "wrfkit doctor"
ui_kv "WRF version" "$WRFKIT_WRF_VERSION"
ui_kv "WPS version" "$WRFKIT_WPS_VERSION"
ui_kv "System" "$(uname -srm)"
printf '\n'

for cmd in gcc g++ gfortran cmake make mpicc mpif90 mpirun nc-config nf-config git python3 tcsh; do
  check_cmd "$cmd"
done

if [[ -n ${SLURM_JOB_ID:-} ]]; then
  check_cmd srun
  printf '\n'
  ui_heading "Slurm allocation"
  ui_kv "job" "$SLURM_JOB_ID"
  ui_kv "step" "${SLURM_STEP_ID:-not set}"
fi

printf '\n'
ui_heading "Versions"

printf '  gcc:       %s\n' "$(gcc -dumpfullversion -dumpversion 2>/dev/null || true)"
printf '  gfortran:  %s\n' "$(gfortran -dumpfullversion -dumpversion 2>/dev/null || true)"
printf '  cmake:     %s\n' "$(cmake --version 2>/dev/null | head -n1 || true)"
printf '  MPI:       %s\n' "$(mpirun --version 2>/dev/null | head -n1 || true)"
printf '  netCDF-C:  %s\n' "$(nc-config --version 2>/dev/null || true)"
printf '  netCDF-F:  %s\n' "$(nf-config --version 2>/dev/null || true)"

printf '\n'
ui_heading "Pinned WRF source"

if [[ -r "$WRFKIT_WRF_ARCHIVE" ]]; then
  ok "$WRFKIT_WRF_ARCHIVE"
else
  fail "WRF archive is unavailable: $WRFKIT_WRF_ARCHIVE"
fi

printf '\n'
ui_heading "Pinned WPS source"

printf '  revision: %s\n' "$WRFKIT_WPS_REV"
if [[ -d "$WRFKIT_WPS_SOURCE" ]]; then
  ok "$WRFKIT_WPS_SOURCE"
else
  fail "WPS source is unavailable: $WRFKIT_WPS_SOURCE"
fi

exit "$status"
