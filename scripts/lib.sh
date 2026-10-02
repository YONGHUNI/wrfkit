#!/usr/bin/env bash

if [[ -z ${WRFKIT_NIX_SHELL:-} ]]; then
  echo "wrfkit: helper must run inside the project Nix environment" >&2
  exit 2
fi

WRFKIT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
WRFKIT_STATE_DIR=${WRFKIT_STATE_DIR:-"$WRFKIT_ROOT/.wrfkit"}
WRFKIT_DATA_DIR=${WRFKIT_DATA_DIR:-"$WRFKIT_STATE_DIR/data"}
WRFKIT_CACHE_DIR=${WRFKIT_CACHE_DIR:-"$WRFKIT_STATE_DIR/cache"}
WRFKIT_GEOG_DIR=${WRFKIT_GEOG_DIR:-"$WRFKIT_DATA_DIR/geog/low-res-mandatory"}
WRFKIT_GFS_DIR=${WRFKIT_GFS_DIR:-"$WRFKIT_DATA_DIR/gfs"}
WRFKIT_WORK_DIR=${WRFKIT_WORK_DIR:-"$WRFKIT_STATE_DIR/work"}

WRFKIT_SRC_DIR=${WRFKIT_SRC_DIR:-"$WRFKIT_STATE_DIR/src/WRF-${WRFKIT_WRF_VERSION}"}

# WRF 4.8.0's configure_new currently runs 'cmake ..' after cd'ing into
# the selected build directory. Therefore the build directory must be a direct
# child of the WRF source tree; an arbitrary sibling/out-of-tree path fails.
WRFKIT_BUILD_DIR=${WRFKIT_BUILD_DIR:-"$WRFKIT_SRC_DIR/_build-wrfkit"}
WRFKIT_INSTALL_DIR=${WRFKIT_INSTALL_DIR:-"$WRFKIT_STATE_DIR/install/wrf-${WRFKIT_WRF_VERSION}"}

WRFKIT_WPS_SRC_DIR=${WRFKIT_WPS_SRC_DIR:-"$WRFKIT_STATE_DIR/src/WPS-${WRFKIT_WPS_VERSION}"}

# WPS 4.7.0 configure_new has the same 'cmake ..' build-directory constraint.
WRFKIT_WPS_BUILD_DIR=${WRFKIT_WPS_BUILD_DIR:-"$WRFKIT_WPS_SRC_DIR/_build-wrfkit"}
WRFKIT_WPS_INSTALL_DIR=${WRFKIT_WPS_INSTALL_DIR:-"$WRFKIT_STATE_DIR/install/wps-${WRFKIT_WPS_VERSION}"}

ensure_wrf_source() {
  [[ -x "$WRFKIT_SRC_DIR/configure_new" ]] && return 0

  [[ -r ${WRFKIT_WRF_ARCHIVE:-} ]] || {
    echo "wrfkit: pinned WRF archive is unavailable" >&2
    exit 2
  }

  rm -rf "$WRFKIT_SRC_DIR"
  mkdir -p "$WRFKIT_SRC_DIR"
  echo "Extracting WRF ${WRFKIT_WRF_VERSION} source..."
  tar -xzf "$WRFKIT_WRF_ARCHIVE" -C "$WRFKIT_SRC_DIR" --strip-components=1

  [[ -x "$WRFKIT_SRC_DIR/configure_new" ]] || {
    echo "wrfkit: extracted WRF source is missing configure_new" >&2
    exit 2
  }
}

ensure_wps_source() {
  local marker="$WRFKIT_WPS_SRC_DIR/.wrfkit-source-rev"

  if [[ -x "$WRFKIT_WPS_SRC_DIR/configure_new" && -r "$marker" ]] &&
     [[ "$(cat "$marker")" == "${WRFKIT_WPS_REV}" ]]; then
    return 0
  fi

  [[ -d ${WRFKIT_WPS_SOURCE:-} ]] || {
    echo "wrfkit: pinned WPS source is unavailable" >&2
    exit 2
  }

  rm -rf "$WRFKIT_WPS_SRC_DIR"
  mkdir -p "$WRFKIT_WPS_SRC_DIR"

  echo "Copying WPS ${WRFKIT_WPS_VERSION} source..."
  cp -a "$WRFKIT_WPS_SOURCE"/. "$WRFKIT_WPS_SRC_DIR"/
  chmod -R u+w "$WRFKIT_WPS_SRC_DIR"
  printf '%s\n' "$WRFKIT_WPS_REV" > "$marker"

  [[ -x "$WRFKIT_WPS_SRC_DIR/configure_new" ]] || {
    echo "wrfkit: copied WPS source is missing configure_new" >&2
    exit 2
  }
}

reset_wps_source() {
  rm -rf "$WRFKIT_WPS_SRC_DIR"
  ensure_wps_source
}


stage_workspace_link() {
  local src=$1 dest=$2

  if [[ -e "$dest" && ! -L "$dest" ]]; then
    printf 'wrfkit: refusing to replace non-symlink workspace file: %s\n' "$dest" >&2
    return 2
  fi

  rm -f "$dest"
  ln -s "$src" "$dest"
}

stage_case_workspace() {
  local case_name=$1
  local case_dir="$WRFKIT_ROOT/cases/$case_name"
  local work_dir="$WRFKIT_WORK_DIR/$case_name"
  local name

  [[ -d "$case_dir" ]] || {
    printf 'wrfkit: case not found: %s\n' "$case_dir" >&2
    return 2
  }

  mkdir -p "$work_dir"

  for name in namelist.wps namelist.input; do
    if [[ -r "$case_dir/$name" ]]; then
      stage_workspace_link "$case_dir/$name" "$work_dir/$name"
    fi
  done

  if [[ -r "$WRFKIT_WPS_SRC_DIR/geogrid/GEOGRID.TBL.ARW" ]]; then
    stage_workspace_link "$WRFKIT_WPS_SRC_DIR/geogrid/GEOGRID.TBL.ARW" "$work_dir/GEOGRID.TBL"
  fi
  if [[ -r "$WRFKIT_WPS_SRC_DIR/metgrid/METGRID.TBL.ARW" ]]; then
    stage_workspace_link "$WRFKIT_WPS_SRC_DIR/metgrid/METGRID.TBL.ARW" "$work_dir/METGRID.TBL"
  fi

  if [[ -r "$case_dir/namelist.wps" ]]; then
    stage_workspace_link "$WRFKIT_GEOG_DIR" "$work_dir/geog"
  fi

  printf '%s' "$work_dir"
}


gfs_request_key() {
  local fingerprint
  fingerprint=$(printf '%s\n' \
    "provider=gfs" \
    "product=${GFS_PRODUCT:-0p25}" \
    "levels=all" \
    "variables=all" \
    "leftlon=$GFS_LEFTLON" \
    "rightlon=$GFS_RIGHTLON" \
    "toplat=$GFS_TOPLAT" \
    "bottomlat=$GFS_BOTTOMLAT" |
    sha256sum | awk '{print substr($1,1,16)}')
  printf '%s' "$fingerprint"
}

gfs_target_dir() {
  local request_key
  request_key=$(gfs_request_key)
  printf '%s/%s/%s/%s/atmos' \
    "$WRFKIT_GFS_DIR" "$GFS_DATE" "$GFS_CYCLE" "$request_key"
}


load_case_env() {
  local case_name=$1 output
  output=$("$WRFKIT_ROOT/scripts/case-config.py" env --case "$case_name") || return $?
  eval "$output"
}


case_config_fingerprint() {
  local case_name=$1
  "$WRFKIT_ROOT/scripts/case-config.py" fingerprint --case "$case_name"
}

file_sha256() {
  local path=$1
  [[ -r "$path" ]] || return 1
  sha256sum "$path" | awk '{print $1}'
}

prep_manifest_path() {
  local case_name=$1
  printf '%s/%s/.wrfkit-prep-manifest' "$WRFKIT_WORK_DIR" "$case_name"
}

write_prep_manifest() {
  local case_name=$1
  local case_dir="$WRFKIT_ROOT/cases/$case_name"
  local work_dir="$WRFKIT_WORK_DIR/$case_name"
  local manifest tmp
  manifest=$(prep_manifest_path "$case_name")
  tmp="${manifest}.tmp"

  mkdir -p "$work_dir"
  cat > "$tmp" <<EOF
schema=1
case=$case_name
case_fingerprint=$(case_config_fingerprint "$case_name")
namelist_wps_sha256=$(file_sha256 "$case_dir/namelist.wps")
namelist_input_sha256=$(file_sha256 "$case_dir/namelist.input")
wrf_version=${WRFKIT_WRF_VERSION:-unknown}
wps_version=${WRFKIT_WPS_VERSION:-unknown}
prepared_at=$(date --iso-8601=seconds 2>/dev/null || date)
EOF
  mv "$tmp" "$manifest"
}

prep_manifest_value() {
  local manifest=$1 key=$2
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$manifest"
}

verify_prep_manifest() {
  local case_name=$1
  local case_dir="$WRFKIT_ROOT/cases/$case_name"
  local manifest expected actual

  manifest=$(prep_manifest_path "$case_name")
  [[ -r "$manifest" ]] || {
    printf 'wrfkit: prepared-case manifest not found: %s\n' "$manifest" >&2
    printf 'Run ./wrfctl prep --case %s first.\n' "$case_name" >&2
    return 2
  }

  expected=$(prep_manifest_value "$manifest" case)
  [[ "$expected" == "$case_name" ]] || {
    printf 'wrfkit: preparation manifest belongs to case %s, not %s\n' "$expected" "$case_name" >&2
    return 2
  }

  expected=$(prep_manifest_value "$manifest" case_fingerprint)
  actual=$(case_config_fingerprint "$case_name")
  [[ -n "$expected" && "$expected" == "$actual" ]] || {
    printf 'wrfkit: case.toml scientific configuration changed after prep.\n' >&2
    printf 'Run ./wrfctl prep --case %s again before ./wrfctl run.\n' "$case_name" >&2
    return 2
  }

  expected=$(prep_manifest_value "$manifest" namelist_wps_sha256)
  actual=$(file_sha256 "$case_dir/namelist.wps" 2>/dev/null || true)
  [[ -n "$expected" && "$expected" == "$actual" ]] || {
    printf 'wrfkit: namelist.wps changed after prep.\n' >&2
    printf 'Run ./wrfctl prep --case %s again before ./wrfctl run.\n' "$case_name" >&2
    return 2
  }

  expected=$(prep_manifest_value "$manifest" namelist_input_sha256)
  actual=$(file_sha256 "$case_dir/namelist.input" 2>/dev/null || true)
  [[ -n "$expected" && "$expected" == "$actual" ]] || {
    printf 'wrfkit: namelist.input changed after prep.\n' >&2
    printf 'Run ./wrfctl prep --case %s again before ./wrfctl run.\n' "$case_name" >&2
    return 2
  }
}
