#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

GEOG_URL=${WRFKIT_GEOG_URL:-https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_low_res_mandatory.tar.gz}
archive="$WRFKIT_CACHE_DIR/geog_low_res_mandatory.tar.gz"
marker="$WRFKIT_GEOG_DIR/.wrfkit-geog-source"

required_dirs=(
  albedo_modis
  greenfrac_fpar_modis_5m
  lai_modis_10m
  maxsnowalb_modis
  modis_landuse_20class_5m_with_lakes
  orogwd_1deg
  soiltemp_1deg
  soiltype_bot_5m
  soiltype_top_5m
  topo_gmted2010_5m
)

geog_complete() {
  local d
  [[ -r "$marker" ]] || return 1
  for d in "${required_dirs[@]}"; do
    [[ -d "$WRFKIT_GEOG_DIR/$d" ]] || return 1
  done
}

if geog_complete; then
  printf 'WPS low-resolution mandatory geography is already available:\n  %s\n' "$WRFKIT_GEOG_DIR"
  exit 0
fi

mkdir -p "$WRFKIT_CACHE_DIR" "$(dirname "$WRFKIT_GEOG_DIR")"

if [[ ! -s "$archive" ]]; then
  partial="$archive.partial"
  rm -f "$partial"
  printf 'Downloading WPS low-resolution mandatory geography...\n'
  printf '  source: %s\n' "$GEOG_URL"
  printf '  cache:  %s\n' "$archive"
  curl --fail --location --retry 3 --retry-delay 2 --output "$partial" "$GEOG_URL"
  mv "$partial" "$archive"
else
  printf 'Using cached geography archive:\n  %s\n' "$archive"
fi

tar -tzf "$archive" >/dev/null

tmp=$(mktemp -d "$(dirname "$WRFKIT_GEOG_DIR")/.geog-extract.XXXXXX")
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT

tar -xzf "$archive" -C "$tmp"

source_dir=""
for candidate in "$tmp" "$tmp/WPS_GEOG" "$tmp/geog"; do
  if [[ -d "$candidate/albedo_modis" ]]; then
    source_dir="$candidate"
    break
  fi
done

[[ -n "$source_dir" ]] || {
  echo "wrfkit: could not locate the geography dataset root in the downloaded archive" >&2
  echo "Top-level archive entries:" >&2
  tar -tzf "$archive" | sed -n '1,20p' >&2
  exit 1
}

rm -rf "$WRFKIT_GEOG_DIR"
mkdir -p "$WRFKIT_GEOG_DIR"
cp -a "$source_dir"/. "$WRFKIT_GEOG_DIR"/

for d in "${required_dirs[@]}"; do
  [[ -d "$WRFKIT_GEOG_DIR/$d" ]] || {
    printf 'wrfkit: downloaded geography is missing expected directory: %s\n' "$d" >&2
    exit 1
  }
done

{
  printf 'url=%s\n' "$GEOG_URL"
  printf 'archive_sha256=%s\n' "$(sha256sum "$archive" | awk '{print $1}')"
  printf 'fetched_at=%s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
} > "$marker"

printf '\nWPS low-resolution mandatory geography ready:\n  %s\n' "$WRFKIT_GEOG_DIR"
printf 'This dataset is intended for smoke tests/education, not production forecasting.\n'
