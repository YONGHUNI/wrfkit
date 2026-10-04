#!/usr/bin/env bash
# Shared terminal UI helpers for wrfkit.
# Auto mode colors interactive terminals only; redirected output remains plain.

ui_color_enabled() {
  local fd=${1:-1}
  [[ -z ${NO_COLOR:-} ]] || return 1
  case "${WRFKIT_COLOR:-auto}" in
    always) return 0 ;;
    never) return 1 ;;
    auto) [[ ${TERM:-dumb} != "dumb" && -t $fd ]] ;;
    *) return 1 ;;
  esac
}

ui_validate_color() {
  case "${WRFKIT_COLOR:-auto}" in
    auto|always|never) ;;
    *)
      ui_error "WRFKIT_COLOR must be auto, always, or never (got: ${WRFKIT_COLOR})."
      return 2
      ;;
  esac
}

ui_heading() {
  if ui_color_enabled 1; then printf '\033[1;36m%s\033[0m\n' "$*"; else printf '%s\n' "$*"; fi
}

ui_step() {
  if ui_color_enabled 1; then printf '\n\033[1;36m==> %s\033[0m\n' "$*"; else printf '\n==> %s\n' "$*"; fi
}

ui_info() {
  if ui_color_enabled 1; then printf '\033[1;36m[INFO]\033[0m %s\n' "$*"; else printf '[INFO] %s\n' "$*"; fi
}

ui_info_err() {
  if ui_color_enabled 2; then printf '\033[1;36m[INFO]\033[0m %s\n' "$*" >&2; else printf '[INFO] %s\n' "$*" >&2; fi
}

ui_ok() {
  if ui_color_enabled 1; then printf '\033[1;32m[OK]\033[0m %s\n' "$*"; else printf '[OK] %s\n' "$*"; fi
}

ui_warn() {
  if ui_color_enabled 2; then printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; else printf '[WARN] %s\n' "$*" >&2; fi
}

ui_fail() {
  if ui_color_enabled 2; then printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; else printf '[FAIL] %s\n' "$*" >&2; fi
}

ui_error() {
  if ui_color_enabled 2; then printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; else printf '[ERROR] %s\n' "$*" >&2; fi
}

ui_kv() {
  local label=$1 value=$2
  if ui_color_enabled 1; then
    printf '  \033[36m%-13s\033[0m \033[1m%s\033[0m\n' "$label:" "$value"
  else
    printf '  %-13s %s\n' "$label:" "$value"
  fi
}
