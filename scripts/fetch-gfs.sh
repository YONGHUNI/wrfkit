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
forcing_conf="$case_dir/forcing.conf"
[[ -r "$forcing_conf" ]] || { printf 'fetch gfs: forcing config not found: %s\n' "$forcing_conf" >&2; exit 2; }

# shellcheck disable=SC1090
source "$forcing_conf"

: "${GFS_DATE:?forcing.conf must define GFS_DATE}"
: "${GFS_CYCLE:?forcing.conf must define GFS_CYCLE}"
: "${GFS_FORECAST_HOURS:?forcing.conf must define GFS_FORECAST_HOURS}"
: "${GFS_LEFTLON:?forcing.conf must define GFS_LEFTLON}"
: "${GFS_RIGHTLON:?forcing.conf must define GFS_RIGHTLON}"
: "${GFS_TOPLAT:?forcing.conf must define GFS_TOPLAT}"
: "${GFS_BOTTOMLAT:?forcing.conf must define GFS_BOTTOMLAT}"

[[ "$GFS_DATE" =~ ^[0-9]{8}$ ]] || { echo "fetch gfs: invalid GFS_DATE" >&2; exit 2; }
[[ "$GFS_CYCLE" =~ ^(00|06|12|18)$ ]] || { echo "fetch gfs: invalid GFS_CYCLE" >&2; exit 2; }

target_dir="$WRFKIT_GFS_DIR/$GFS_DATE/$GFS_CYCLE/atmos"
mkdir -p "$target_dir"
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
  curl --fail --location --retry 3 --retry-delay 2 --output "$partial" "$url"
  [[ -s "$partial" ]] || { printf 'fetch gfs: empty download for f%s\n' "$fh" >&2; exit 1; }
  mv "$partial" "$dest"
done

printf '\nGFS forcing ready:\n  %s\n' "$target_dir"
printf 'Source: NOAA/NCEP NOMADS GFS 0.25-degree GRIB filter\n'
