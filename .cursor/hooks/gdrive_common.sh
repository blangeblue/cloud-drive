#!/usr/bin/env bash
# Shared helpers for the Google Drive sync hooks.
# Not executed directly; sourced by gdrive_pull.sh / gdrive_push.sh.

GDRIVE_HOOK_LOG="${GDRIVE_HOOK_LOG:-/tmp/gdrive_hook.log}"

gdrive_root() {
  # Prefer the dir Cursor passes; fall back to two levels up from this file.
  if [ -n "${CURSOR_PROJECT_DIR:-}" ]; then
    printf '%s' "${CURSOR_PROJECT_DIR}"
  else
    (cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  fi
}

gdrive_log() { echo "[$(date -u +%FT%TZ)] $*" >> "${GDRIVE_HOOK_LOG}" 2>&1; }

gdrive_have_creds() {
  [ -n "${GDRIVE_SERVICE_ACCOUNT_JSON:-}${RCLONE_GDRIVE_TOKEN:-}" ]
}

# Export RCLONE_CONFIG_GDRIVE_* env for an ad-hoc "gdrive" remote.
# Arg 1 = scope (e.g. drive.readonly or drive). Echoes a temp SA file path (if any)
# on fd so the caller can clean it up via GDRIVE_TMP_SA.
gdrive_configure_remote() {
  local scope="${1:-drive.readonly}"
  export RCLONE_CONFIG_GDRIVE_TYPE="drive"
  export RCLONE_CONFIG_GDRIVE_SCOPE="${scope}"
  GDRIVE_TMP_SA=""
  if [ -n "${GDRIVE_SERVICE_ACCOUNT_JSON:-}" ]; then
    GDRIVE_TMP_SA="$(mktemp)"
    printf '%s' "${GDRIVE_SERVICE_ACCOUNT_JSON}" > "${GDRIVE_TMP_SA}"
    export RCLONE_CONFIG_GDRIVE_SERVICE_ACCOUNT_FILE="${GDRIVE_TMP_SA}"
  elif [ -n "${RCLONE_GDRIVE_TOKEN:-}" ]; then
    export RCLONE_CONFIG_GDRIVE_TOKEN="${RCLONE_GDRIVE_TOKEN}"
    [ -n "${GDRIVE_CLIENT_ID:-}" ]     && export RCLONE_CONFIG_GDRIVE_CLIENT_ID="${GDRIVE_CLIENT_ID}"
    [ -n "${GDRIVE_CLIENT_SECRET:-}" ] && export RCLONE_CONFIG_GDRIVE_CLIENT_SECRET="${GDRIVE_CLIENT_SECRET}"
  fi
}

gdrive_cleanup_remote() { [ -n "${GDRIVE_TMP_SA:-}" ] && rm -f "${GDRIVE_TMP_SA}"; }

gdrive_shared_flag() {
  case "${GDRIVE_SHARED_WITH_ME:-1}" in
    1|true|TRUE|yes|YES) echo "--drive-shared-with-me" ;;
    *) echo "" ;;
  esac
}
