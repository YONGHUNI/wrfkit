#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

usage() { echo "Usage: ./wrfctl fetch gfs --case NAME" >&2; }

case_name=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case) [[ $# -ge 2 ]] || { usage; exit 2; }; case_name=$2; shift 2 ;;
    --case=*) case_name=${1#--case=}; shift ;;
    *) printf 'fetch gfs: unexpected argument: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$case_name" ]] || { usage; exit 2; }
[[ "$case_name" =~ ^[A-Za-z0-9._-]+$ ]] || { printf 'fetch gfs: invalid case name: %s\n' "$case_name" >&2; exit 2; }

case_dir="$WRFKIT_ROOT/cases/$case_name"
[[ -r "$case_dir/case.toml" ]] || { printf 'fetch gfs: case config not found: %s\n' "$case_dir/case.toml" >&2; exit 2; }

load_case_env "$case_name"

: "${GFS_DATE:?case.toml did not resolve a GFS date}"
: "${GFS_CYCLE:?case.toml did not resolve a GFS cycle}"
: "${GFS_FORECAST_HOURS:?case.toml did not resolve forecast hours}"
: "${GFS_LEFTLON:?case.toml did not resolve forcing.subset.west}"
: "${GFS_RIGHTLON:?case.toml did not resolve forcing.subset.east}"
: "${GFS_TOPLAT:?case.toml did not resolve forcing.subset.north}"
: "${GFS_BOTTOMLAT:?case.toml did not resolve forcing.subset.south}"

[[ "$GFS_DATE" =~ ^[0-9]{8}$ ]] || { echo "fetch gfs: invalid GFS_DATE" >&2; exit 2; }
[[ "$GFS_CYCLE" =~ ^(00|06|12|18)$ ]] || { echo "fetch gfs: invalid GFS_CYCLE" >&2; exit 2; }

human_bytes() {
  local bytes=$1
  awk -v b="$bytes" 'BEGIN {
    if (b >= 1073741824) printf "%.2f GiB", b / 1073741824;
    else if (b >= 1048576) printf "%.2f MiB", b / 1048576;
    else if (b >= 1024) printf "%.1f KiB", b / 1024;
    else printf "%d B", b;
  }'
}

human_rate() {
  local bytes_per_sec=$1
  awk -v b="$bytes_per_sec" 'BEGIN {
    if (b >= 1048576) printf "%.2f MiB/s", b / 1048576;
    else if (b >= 1024) printf "%.1f KiB/s", b / 1024;
    else printf "%d B/s", b;
  }'
}

format_elapsed() {
  local seconds=$1
  printf '%02d:%02d' "$((seconds / 60))" "$((seconds % 60))"
}

download_with_progress() {
  local url=$1 output=$2
  local err_file start now elapsed size rate pid rc

  err_file="${output}.curl-error"
  rm -f "$err_file"
  start=$(date +%s)

  curl --fail --location --retry 3 --retry-delay 2 \
    --silent --show-error --output "$output" "$url" 2>"$err_file" &
  pid=$!

  if [[ -t 1 ]]; then
    while kill -0 "$pid" 2>/dev/null; do
      size=0
      [[ -f "$output" ]] && size=$(stat -c %s "$output" 2>/dev/null || printf '0')
      now=$(date +%s)
      elapsed=$((now - start))
      ((elapsed > 0)) || elapsed=1
      rate=$((size / elapsed))
      printf '\r  downloaded: %-10s elapsed: %s  avg: %-12s' \
        "$(human_bytes "$size")" "$(format_elapsed "$elapsed")" "$(human_rate "$rate")"
      sleep 1
    done
  fi

  if wait "$pid"; then
    rc=0
  else
    rc=$?
  fi

  now=$(date +%s)
  elapsed=$((now - start))
  ((elapsed > 0)) || elapsed=1
  size=0
  [[ -f "$output" ]] && size=$(stat -c %s "$output" 2>/dev/null || printf '0')
  rate=$((size / elapsed))

  if [[ -t 1 ]]; then
    printf '\r%-79s\r' ''
  fi

  if ((rc != 0)); then
    [[ -s "$err_file" ]] && cat "$err_file" >&2
    rm -f "$err_file"
    return "$rc"
  fi

  rm -f "$err_file"
  printf '  downloaded: %s | elapsed: %s | avg: %s\n' \
    "$(human_bytes "$size")" "$(format_elapsed "$elapsed")" "$(human_rate "$rate")"
}

target_dir=$(gfs_target_dir)
mkdir -p "$target_dir"

cat > "$target_dir/.wrfkit-request" <<EOF
provider=gfs
product=$GFS_PRODUCT
date=$GFS_DATE
cycle=$GFS_CYCLE
leftlon=$GFS_LEFTLON
rightlon=$GFS_RIGHTLON
toplat=$GFS_TOPLAT
bottomlat=$GFS_BOTTOMLAT
levels=all
variables=all
EOF
base_url="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25.pl"

for fh in $GFS_FORECAST_HOURS; do
  [[ "$fh" =~ ^[0-9]{3}$ ]] || { printf 'fetch gfs: invalid forecast hour: %s\n' "$fh" >&2; exit 2; }
  file="gfs.t${GFS_CYCLE}z.pgrb2.0p25.f${fh}"
  dest="$target_dir/$file"

  if [[ -s "$dest" ]]; then
    printf 'Using cached GFS file: %s\n' "$dest"
    continue
  fi

  url="${base_url}?file=${file}&all_lev=on&all_var=on&subregion=&leftlon=${GFS_LEFTLON}&rightlon=${GFS_RIGHTLON}&toplat=${GFS_TOPLAT}&bottomlat=${GFS_BOTTOMLAT}&dir=%2Fgfs.${GFS_DATE}%2F${GFS_CYCLE}%2Fatmos"
  partial="$dest.partial"
  rm -f "$partial"
  printf 'Downloading GFS %sZ f%s subset...\n' "$GFS_CYCLE" "$fh"
  if ! download_with_progress "$url" "$partial"; then
    printf 'fetch gfs: download failed for f%s\n' "$fh" >&2
    exit 1
  fi
  [[ -s "$partial" ]] || { printf 'fetch gfs: empty download for f%s\n' "$fh" >&2; exit 1; }
  mv "$partial" "$dest"
done

printf '\nGFS forcing ready:\n  %s\n' "$target_dir"
printf 'Source: NOAA/NCEP NOMADS GFS 0.25-degree GRIB filter\n'
