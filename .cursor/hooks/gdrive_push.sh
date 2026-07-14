#!/usr/bin/env bash
#
# Cursor hook: push local workspace changes back to the Google Drive folder.
# Wired to `stop` (fires for cloud + local at the end of each agent turn) and
# `sessionEnd` (local IDE only). Uploads only Drive-derived data; repo/tooling
# files are excluded.
#
# NOTE: uploading requires write access. A plain service account CANNOT upload to
# a personal ("My Drive") folder — Google returns 403 storageQuotaExceeded. Use
# an OAuth user token (RCLONE_GDRIVE_TOKEN) or a Shared Drive for push to work.
#
# Contract: reads hook JSON on stdin (ignored), prints JSON on stdout. Non-fatal
# and non-blocking: all real output goes to the log; only "{}" is printed.
set -uo pipefail

cat >/dev/null 2>&1 || true

DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=/dev/null
. "${DIR}/gdrive_common.sh"

ROOT="$(gdrive_root)"
LOCAL_DIR="${GDRIVE_LOCAL_DIR:-${ROOT}}"
FOLDER="${GDRIVE_FOLDER:-agent 工作区}"

{
  gdrive_log "push: start dir='${LOCAL_DIR}' folder='${FOLDER}'"
  if [ "${GDRIVE_PUSH_ENABLED:-0}" != "1" ]; then
    gdrive_log "push: disabled (set GDRIVE_PUSH_ENABLED=1 after enabling write access)"
  elif ! gdrive_have_creds; then
    gdrive_log "push: skipped (no credentials)"
  else
    # Prefer the OAuth token: a service account cannot upload to personal Drive.
    gdrive_configure_remote "${GDRIVE_PUSH_SCOPE:-drive}" token
    gdrive_log "push: auth=${GDRIVE_ACTIVE_AUTH:-none}"
    # Shared-with-me depends on the auth identity: for the token (folder owner)
    # the folder is in "My Drive" (no flag); for a service account it is shared.
    if [ "${GDRIVE_ACTIVE_AUTH}" = "token" ]; then
      _swm_default=0
    else
      _swm_default="${GDRIVE_SHARED_WITH_ME:-1}"
    fi
    case "${GDRIVE_PUSH_SHARED_WITH_ME:-${_swm_default}}" in
      1|true|TRUE|yes|YES) SHARED_FLAG="--drive-shared-with-me" ;;
      *) SHARED_FLAG="" ;;
    esac
    # Exclude repo/tooling files so only Drive-derived content is pushed back.
    if rclone copy "${LOCAL_DIR}" "gdrive:${FOLDER}" ${SHARED_FLAG} \
         --exclude "/.git/**" \
         --exclude "/.cursor/**" \
         --exclude "/scripts/**" \
         --exclude "/README.md" \
         --exclude "/AGENTS.md" \
         --exclude "/.gitignore" \
         >>"${GDRIVE_HOOK_LOG}" 2>&1; then
      gdrive_log "push: ok"
    else
      gdrive_log "push: FAILED (write access? service accounts cannot upload to a personal Drive — use an OAuth token or Shared Drive)"
    fi
    gdrive_cleanup_remote
  fi
} >>"${GDRIVE_HOOK_LOG}" 2>&1

printf '{}'
