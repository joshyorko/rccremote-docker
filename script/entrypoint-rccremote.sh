#!/usr/bin/env bash
set -euo pipefail

ROBOTS_PATH="${ROBOTS_PATH:-/robots}"
HOLOLIB_ZIP_PATH="${HOLOLIB_ZIP_PATH:-/hololib_zip}"
HOLOLIB_ZIP_PATH_INT="${HOLOLIB_ZIP_PATH_INT:-/hololib_zip_internal}"
RCCREMOTE_HOSTNAME="${RCCREMOTE_HOSTNAME:-0.0.0.0}"
RCCREMOTE_PORT="${RCCREMOTE_PORT:-4653}"
RCCREMOTE_DEBUG="${RCCREMOTE_DEBUG:-true}"

log() {
  printf '[rccremote-entrypoint] %s\n' "$*"
}

restore_environment() {
  local saved_env="${1:-}"
  if [[ -n "$saved_env" && -f "$saved_env" ]]; then
    unset ROBOCORP_HOME
    # shellcheck disable=SC1090
    . "$saved_env"
    rm -f "$saved_env"
  fi
}

disable_telemetry() {
  # No-op if telemetry was already disabled.
  rcc config identity -t >/dev/null 2>&1 || true
}

configure_shared_holotree() {
  log "Enabling shared holotree..."
  rcc ht shared -e >/dev/null 2>&1 || true
  rcc ht init >/dev/null 2>&1 || true
}

build_and_import_robot_catalogs() {
  mkdir -p "$ROBOTS_PATH" "$HOLOLIB_ZIP_PATH_INT"

  local found=0
  while IFS= read -r robot_yaml; do
    found=1
    local robot_dir robot_name zip_file saved_env
    robot_dir="$(dirname "$robot_yaml")"
    robot_name="$(basename "$robot_dir")"
    zip_file="$HOLOLIB_ZIP_PATH_INT/${robot_name}.zip"
    saved_env=""

    if [[ ! -f "$robot_dir/conda.yaml" ]]; then
      log "Skipping '${robot_name}' (missing conda.yaml)."
      continue
    fi

    if [[ -f "$robot_dir/.env" ]]; then
      saved_env="$(mktemp)"
      export -p >"$saved_env"
      set -a
      # shellcheck disable=SC1090
      . "$robot_dir/.env"
      set +a
    fi

    log "Building catalog for '${robot_name}'..."
    rcc ht vars -r "$robot_yaml"
    rcc ht export -r "$robot_yaml" -z "$zip_file"
    rcc holotree import "$zip_file"

    restore_environment "$saved_env"
  done < <(find "$ROBOTS_PATH" -type f -name "robot.yaml" | sort)

  if [[ "$found" -eq 0 ]]; then
    log "No robot definitions found in '$ROBOTS_PATH'."
  fi
}

import_mounted_zip_catalogs() {
  mkdir -p "$HOLOLIB_ZIP_PATH"

  shopt -s nullglob
  local zip
  for zip in "$HOLOLIB_ZIP_PATH"/*.zip; do
    log "Importing mounted ZIP catalog: $zip"
    rcc holotree import "$zip"
  done
  shopt -u nullglob
}

print_catalogs() {
  log "Current catalogs:"
  rcc holotree catalogs || true
}

start_rccremote() {
  local args
  args=(--hostname "$RCCREMOTE_HOSTNAME" --port "$RCCREMOTE_PORT")
  if [[ "$RCCREMOTE_DEBUG" == "true" ]]; then
    args+=(--debug --trace)
  fi

  log "Starting rccremote on ${RCCREMOTE_HOSTNAME}:${RCCREMOTE_PORT}..."
  exec rccremote "${args[@]}"
}

main() {
  disable_telemetry
  configure_shared_holotree
  build_and_import_robot_catalogs
  import_mounted_zip_catalogs
  print_catalogs
  start_rccremote
}

main "$@"
