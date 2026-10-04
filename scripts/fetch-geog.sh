#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: ./wrfctl fetch geog [--case NAME]

Without --case, fetch the low-resolution mandatory package used by the
athens-minimal validation case. With --case, resolve the geography package
from cases/NAME/case.toml.
USAGE
}

total_start=$SECONDS
download_seconds=0
hash_seconds=0
extract_seconds=0

case_name=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      case_name=$2
      shift 2
      ;;
    --case=*)
      case_name=${1#--case=}
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'fetch geog: unexpected argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "$case_name" ]]; then
  load_case_env "$case_name"
else
  GEOG_DATASET=wps-lowres-mandatory
  GEOG_RESOLUTION=lowres
  GEOG_MANAGEMENT=managed
  GEOG_AUTO_ACQUIRE=1
  export GEOG_DATASET GEOG_RESOLUTION GEOG_MANAGEMENT GEOG_AUTO_ACQUIRE
fi

[[ "$GEOG_MANAGEMENT" == "managed" ]] || {
  ui_error "fetch geog does not download user-provided geography."
  printf 'Case %s uses dataset=%s. Provide the configured external path instead.\n' \
    "${case_name:-<none>}" "$GEOG_DATASET" >&2
  exit 2
}

SOURCE_PAGE=https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html

case "$GEOG_DATASET" in
  wps-lowres-mandatory)
    package_label="WPS low-resolution mandatory geography"
    archive_name=geog_low_res_mandatory.tar.gz
    default_url=https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_low_res_mandatory.tar.gz
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
    ;;
  wps-highres-mandatory)
    package_label="WPS high-resolution mandatory geography"
    archive_name=geog_high_res_mandatory.tar.gz
    default_url=https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_high_res_mandatory.tar.gz
    required_dirs=(
      albedo_modis
      greenfrac_fpar_modis
      lai_modis_10m
      lai_modis_30s
      maxsnowalb_modis
      modis_landuse_20class_30s_with_lakes
      orogwd_2deg
      orogwd_1deg
      orogwd_30m
      orogwd_20m
      orogwd_10m
      soiltemp_1deg
      soiltype_bot_30s
      soiltype_top_30s
      topo_gmted2010_30s
      varsso
      varsso_10m
      varsso_5m
      varsso_2m
    )
    ;;
  *)
    ui_error "No geography downloader is defined for dataset=$GEOG_DATASET"
    exit 2
    ;;
esac

GEOG_URL=${WRFKIT_GEOG_URL:-$default_url}
archive_root=${WRFKIT_GEOG_ARCHIVE_DIR:-"$WRFKIT_GEOG_ROOT/.archives"}
archive="$archive_root/$archive_name"
legacy_archive="$WRFKIT_CACHE_DIR/$archive_name"
marker="$WRFKIT_GEOG_DIR/.wrfkit-geog-source"
partial=""

marker_matches_dataset() {
  local marker_path=$1
  [[ -r "$marker_path" ]] || return 1

  if grep -Fxq "dataset=$GEOG_DATASET" "$marker_path"; then
    return 0
  fi

  # Compatibility with low-resolution installations created before the marker
  # recorded an explicit dataset name.
  if [[ "$GEOG_DATASET" == "wps-lowres-mandatory" ]] &&
     grep -Fxq "url=https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_low_res_mandatory.tar.gz" "$marker_path"; then
    return 0
  fi

  return 1
}

geog_complete_at() {
  local root=$1 d
  [[ -d "$root" ]] || return 1
  marker_matches_dataset "$root/.wrfkit-geog-source" || return 1
  for d in "${required_dirs[@]}"; do
    [[ -d "$root/$d" ]] || return 1
  done
}

if geog_complete_at "$WRFKIT_GEOG_DIR"; then
  printf '%s is already available:\n  %s\n' "$package_label" "$WRFKIT_GEOG_DIR"
  exit 0
fi

mkdir -p "$archive_root" "$(dirname "$WRFKIT_GEOG_DIR")"

# Reuse the old project-local low-resolution archive if it already exists.
# New downloads live with the geography data so a shared data_root does not
# create a second multi-gigabyte archive in every repository clone.
if [[ ! -s "$archive" && "$GEOG_DATASET" == "wps-lowres-mandatory" && -s "$legacy_archive" ]]; then
  archive="$legacy_archive"
fi

cleanup() {
  [[ -z "$partial" ]] || rm -f "$partial"
  [[ -z ${tmp:-} ]] || rm -rf "$tmp"
}
trap cleanup EXIT

if [[ ! -s "$archive" ]]; then
  partial="$archive_root/.$archive_name.partial.$$"
  rm -f "$partial"

  ui_heading "Download static geography"
  ui_kv "dataset" "$GEOG_DATASET"
  ui_kv "source" "$GEOG_URL"
  ui_kv "archive" "$archive"
  if [[ "$GEOG_DATASET" == "wps-highres-mandatory" ]]; then
    ui_info "The official package is large; keep data_root on persistent storage."
  fi

  phase_start=$SECONDS
  curl --fail --location --retry 3 --retry-delay 2 --output "$partial" "$GEOG_URL"
  download_seconds=$((SECONDS - phase_start))

  # Avoid a separate tar -tzf pass. The real extraction below reads the
  # gzip/tar stream once and serves as the integrity check.
  mv --no-clobber "$partial" "$archive" 2>/dev/null || true
  rm -f "$partial"
  partial=""
else
  ui_info "Using cached geography archive: $archive"
fi

[[ -s "$archive" ]] || {
  ui_error "Geography archive is missing or empty: $archive"
  exit 1
}

phase_start=$SECONDS
archive_sha256=$(sha256sum "$archive" | awk '{print $1}')
hash_seconds=$((SECONDS - phase_start))

parent=$(dirname "$WRFKIT_GEOG_DIR")
tmp=$(mktemp -d "$parent/.geog-extract.XXXXXX")
payload="$tmp/payload"
mkdir -p "$payload"

ui_info "Extracting $GEOG_DATASET."
phase_start=$SECONDS
if ! tar -xzf "$archive" -C "$payload"; then
  extract_seconds=$((SECONDS - phase_start))
  ui_error "Geography extraction failed after ${extract_seconds}s."
  ui_warn "The cached archive was kept for diagnosis or retry."
  exit 1
fi
extract_seconds=$((SECONDS - phase_start))

source_dir=""
if [[ -d "$payload/${required_dirs[0]}" ]]; then
  source_dir="$payload"
else
  while IFS= read -r candidate; do
    if [[ -d "$candidate/${required_dirs[0]}" ]]; then
      source_dir="$candidate"
      break
    fi
  done < <(find "$payload" -mindepth 1 -maxdepth 1 -type d -print)
fi

[[ -n "$source_dir" ]] || {
  ui_error "Could not locate the geography dataset root in the downloaded archive."
  printf 'Top-level archive entries:\n' >&2
  tar -tzf "$archive" | sed -n '1,20p' >&2
  exit 1
}

for d in "${required_dirs[@]}"; do
  [[ -d "$source_dir/$d" ]] || {
    ui_error "Downloaded $GEOG_DATASET is missing expected directory: $d"
    exit 1
  }
done

prepared="$tmp/prepared"
mv "$source_dir" "$prepared"

{
  printf 'schema=1\n'
  printf 'dataset=%s\n' "$GEOG_DATASET"
  printf 'source_page=%s\n' "$SOURCE_PAGE"
  printf 'url=%s\n' "$GEOG_URL"
  printf 'archive=%s\n' "$archive_name"
  printf 'archive_sha256=%s\n' "$archive_sha256"
  printf 'fetched_at=%s\n' "$(date --iso-8601=seconds 2>/dev/null || date)"
} > "$prepared/.wrfkit-geog-source"

# Installation is atomic within the geography filesystem: extract and validate
# in a sibling temporary directory, then rename the complete tree into place.
# If another process won the race, accept its complete installation.
if [[ -e "$WRFKIT_GEOG_DIR" ]]; then
  if geog_complete_at "$WRFKIT_GEOG_DIR"; then
    ui_ok "$package_label became available while this process was extracting."
    exit 0
  fi
  rm -rf "$WRFKIT_GEOG_DIR"
fi

if ! mv -T "$prepared" "$WRFKIT_GEOG_DIR" 2>/dev/null; then
  if geog_complete_at "$WRFKIT_GEOG_DIR"; then
    ui_ok "$package_label became available while this process was installing."
    exit 0
  fi
  ui_error "Could not install geography at $WRFKIT_GEOG_DIR"
  exit 1
fi

geog_complete_at "$WRFKIT_GEOG_DIR" || {
  ui_error "Installed geography failed the final completeness check."
  exit 1
}

printf '\n'
ui_ok "$package_label ready."
ui_kv "dataset" "$GEOG_DATASET"
ui_kv "path" "$WRFKIT_GEOG_DIR"
ui_kv "archive sha256" "$archive_sha256"
ui_heading "Acquisition timing"
(( download_seconds > 0 )) && ui_kv "download" "${download_seconds}s"
ui_kv "sha256" "${hash_seconds}s"
ui_kv "extract" "${extract_seconds}s"
ui_kv "total" "$((SECONDS - total_start))s"
if [[ "$GEOG_DATASET" == "wps-lowres-mandatory" ]]; then
  ui_info "This package is intended for workflow validation/education."
fi
