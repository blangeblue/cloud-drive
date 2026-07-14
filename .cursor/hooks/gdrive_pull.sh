#!/usr/bin/env bash
#
# Cursor hook: pull the configured Google Drive folder into the local workspace.
# Wired to `sessionStart` (fires for local IDE agents). Cloud agents pull on VM
# boot via .cursor/environment.json instead (sessionStart does not fire in cloud).
#
# Contract: reads hook JSON on stdin (ignored), prints JSON on stdout. Non-fatal
# and non-blocking: all real output goes to the log; only "{}" is printed.
set -uo pipefail

# Consume stdin so the caller's pipe never blocks.
cat >/dev/null 2>&1 || true

DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=/dev/null
. "${DIR}/gdrive_common.sh"

ROOT="$(gdrive_root)"
SCRIPT="${ROOT}/scripts/sync_gdrive.sh"

{
  gdrive_log "pull: start"
  if ! gdrive_have_creds; then
    gdrive_log "pull: skipped (no GDRIVE_SERVICE_ACCOUNT_JSON / RCLONE_GDRIVE_TOKEN)"
  elif [ ! -f "${SCRIPT}" ]; then
    gdrive_log "pull: skipped (missing ${SCRIPT})"
  else
    if GDRIVE_SHARED_WITH_ME="${GDRIVE_SHARED_WITH_ME:-1}" \
       GDRIVE_FOLDER="${GDRIVE_FOLDER:-agent 工作区}" \
       GDRIVE_LOCAL_DIR="${GDRIVE_LOCAL_DIR:-${ROOT}}" \
       GDRIVE_SYNC_MODE="${GDRIVE_SYNC_MODE:-mirror}" \
       bash "${SCRIPT}" >>"${GDRIVE_HOOK_LOG}" 2>&1; then
      gdrive_log "pull: ok"
    else
      gdrive_log "pull: FAILED (see above)"
    fi
  fi
} >>"${GDRIVE_HOOK_LOG}" 2>&1

printf '{}'
