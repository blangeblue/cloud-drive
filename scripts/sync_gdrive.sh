#!/usr/bin/env bash
#
# Sync files from Google Drive into a local directory so they can be used as
# context for agent tasks running inside this VM.
#
# It uses rclone (https://rclone.org) and configures the remote entirely through
# environment variables, so no `rclone config` / interactive login is required.
#
# ---------------------------------------------------------------------------
# Credentials (choose ONE method):
#
#   Method A - Service account (recommended for automation / headless VMs):
#     GDRIVE_SERVICE_ACCOUNT_JSON  Full JSON content of a Google Cloud service
#                                  account key. Share the Drive folder(s) you
#                                  want to sync with the service account's email
#                                  (or place them on a Shared Drive the account
#                                  can access).
#
#   Method B - OAuth token from your own machine:
#     RCLONE_GDRIVE_TOKEN          The `token` JSON produced by running
#                                  `rclone config` locally for a `drive` remote.
#     GDRIVE_CLIENT_ID  (optional) Your own Google OAuth client id.
#     GDRIVE_CLIENT_SECRET (optional) Your own Google OAuth client secret.
#
# ---------------------------------------------------------------------------
# Configuration (all optional):
#
#   GDRIVE_FOLDER      Drive folder path or folder ID to sync.
#                      Empty = sync from the Drive root.
#   GDRIVE_LOCAL_DIR   Local target directory. Default: <repo>/gdrive-context
#   GDRIVE_SCOPE       rclone drive scope. Default: drive.readonly
#   GDRIVE_SHARED_WITH_ME  Set to 1/true to sync from "Shared with me" instead
#                      of "My Drive". Required when a folder was *shared* with a
#                      service account (shared items do not appear under the
#                      account's own Drive root).
#
# Any extra arguments are passed straight through to `rclone copy`.
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${GDRIVE_LOCAL_DIR:-${REPO_ROOT}/gdrive-context}"
SCOPE="${GDRIVE_SCOPE:-drive.readonly}"
REMOTE="gdrive"

if ! command -v rclone >/dev/null 2>&1; then
  echo "ERROR: rclone is not installed. Install it with:" >&2
  echo "  curl -fsSL https://rclone.org/install.sh | sudo bash" >&2
  exit 1
fi

# Configure the rclone remote purely via environment variables.
export RCLONE_CONFIG_GDRIVE_TYPE="drive"
export RCLONE_CONFIG_GDRIVE_SCOPE="${SCOPE}"

tmp_sa=""
cleanup() { [ -n "${tmp_sa}" ] && rm -f "${tmp_sa}"; }
trap cleanup EXIT

if [ -n "${GDRIVE_SERVICE_ACCOUNT_JSON:-}" ]; then
  echo "Auth: service account"
  tmp_sa="$(mktemp)"
  printf '%s' "${GDRIVE_SERVICE_ACCOUNT_JSON}" > "${tmp_sa}"
  export RCLONE_CONFIG_GDRIVE_SERVICE_ACCOUNT_FILE="${tmp_sa}"
elif [ -n "${RCLONE_GDRIVE_TOKEN:-}" ]; then
  echo "Auth: OAuth token"
  export RCLONE_CONFIG_GDRIVE_TOKEN="${RCLONE_GDRIVE_TOKEN}"
  [ -n "${GDRIVE_CLIENT_ID:-}" ]     && export RCLONE_CONFIG_GDRIVE_CLIENT_ID="${GDRIVE_CLIENT_ID}"
  [ -n "${GDRIVE_CLIENT_SECRET:-}" ] && export RCLONE_CONFIG_GDRIVE_CLIENT_SECRET="${GDRIVE_CLIENT_SECRET}"
else
  echo "ERROR: no Google Drive credentials found." >&2
  echo "Set GDRIVE_SERVICE_ACCOUNT_JSON (service account) or" >&2
  echo "RCLONE_GDRIVE_TOKEN (OAuth token). See the header of this script." >&2
  exit 1
fi

SRC="${REMOTE}:"
if [ -n "${GDRIVE_FOLDER:-}" ]; then
  SRC="${REMOTE}:${GDRIVE_FOLDER}"
fi

EXTRA_FLAGS=()
case "${GDRIVE_SHARED_WITH_ME:-}" in
  1|true|TRUE|yes|YES) EXTRA_FLAGS+=(--drive-shared-with-me) ;;
esac

mkdir -p "${LOCAL_DIR}"

echo "Syncing '${SRC}' -> '${LOCAL_DIR}' (scope=${SCOPE})"
rclone copy "${SRC}" "${LOCAL_DIR}" --fast-list --drive-acknowledge-abuse "${EXTRA_FLAGS[@]}" "$@"

echo "Done. Files available under: ${LOCAL_DIR}"
echo "--- top-level contents ---"
rclone lsf "${SRC}" "${EXTRA_FLAGS[@]}" 2>/dev/null | head -50 || true
