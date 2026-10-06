#!/usr/bin/env bash

# Host CPU-resource discovery shared by bootstrap and wrfctl.
# These helpers report capacity visible to the current process; they do not
# claim to choose a performance-optimal MPI rank count.

wrfkit_detect_available_logical_cpus() {
  local count=""

  if command -v nproc >/dev/null 2>&1; then
    # GNU nproc can honor OpenMP environment limits. Those variables describe
    # an application runtime policy, not the machine capacity wrfkit is trying
    # to discover here, so ignore them only for this probe.
    count=$(env -u OMP_NUM_THREADS -u OMP_THREAD_LIMIT nproc 2>/dev/null || true)
  fi

  if [[ ! "$count" =~ ^[1-9][0-9]*$ ]] && command -v getconf >/dev/null 2>&1; then
    count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)
  fi

  [[ "$count" =~ ^[1-9][0-9]*$ ]] || return 1
  printf '%s\n' "$count"
}

wrfkit_cpu_in_list() {
  local cpu=$1 spec=$2 item start end
  local -a items=()

  spec=${spec//[[:space:]]/}
  IFS=',' read -r -a items <<< "$spec"

  for item in "${items[@]}"; do
    if [[ "$item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      start=${BASH_REMATCH[1]}
      end=${BASH_REMATCH[2]}
      (( cpu >= start && cpu <= end )) && return 0
    elif [[ "$item" =~ ^[0-9]+$ ]] && (( cpu == item )); then
      return 0
    fi
  done
  return 1
}

wrfkit_detect_available_physical_cores() {
  local allowed cpu_dir cpu package core
  local -A seen=()

  [[ -r /proc/self/status && -d /sys/devices/system/cpu ]] || return 1
  allowed=$(awk '/^Cpus_allowed_list:/ { print $2; exit }' /proc/self/status)
  [[ -n "$allowed" ]] || return 1

  for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
    [[ -d "$cpu_dir" ]] || continue
    cpu=${cpu_dir##*cpu}
    [[ "$cpu" =~ ^[0-9]+$ ]] || continue
    wrfkit_cpu_in_list "$cpu" "$allowed" || continue

    [[ -r "$cpu_dir/topology/physical_package_id" ]] || continue
    [[ -r "$cpu_dir/topology/core_id" ]] || continue
    package=$(<"$cpu_dir/topology/physical_package_id")
    core=$(<"$cpu_dir/topology/core_id")
    [[ "$package" =~ ^-?[0-9]+$ && "$core" =~ ^-?[0-9]+$ ]] || continue
    seen["$package:$core"]=1
  done

  (("${#seen[@]}" > 0)) || return 1
  printf '%s\n' "${#seen[@]}"
}

wrfkit_derive_default_mpi_tasks() {
  local logical physical default

  logical=$(wrfkit_detect_available_logical_cpus) || return 1

  if physical=$(wrfkit_detect_available_physical_cores 2>/dev/null) &&
     [[ "$physical" =~ ^[1-9][0-9]*$ ]]; then
    if (( physical < logical )); then
      default=$physical
    else
      default=$logical
    fi
  else
    # Topology is unavailable. Half of the visible logical CPUs is only a
    # transparent fallback heuristic, not a performance recommendation.
    default=$((logical / 2))
    (( default >= 1 )) || default=1
  fi

  printf '%s\n' "$default"
}
