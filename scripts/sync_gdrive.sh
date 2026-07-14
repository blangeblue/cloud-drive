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
#   GDRIVE_SYNC_MODE   "copy" (default, add-only) or "mirror". Mirror uses
#                      `rclone sync` so files deleted on Drive are also removed
#                      locally. Repo/tooling files are protected from deletion
#                      (static list + everything tracked by git).
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

# Mode: "copy" (default, add-only) or "mirror" (rclone sync, propagates Drive
# deletions to the local copy). Mirror is required if you want files deleted on
# Drive to also disappear locally instead of lingering forever.
MODE="copy"
case "${GDRIVE_SYNC_MODE:-copy}" in
  mirror|sync|MIRROR|SYNC) MODE="sync" ;;
esac

# In mirror mode `rclone sync` deletes destination files that are absent from the
# source. When the destination is (or is inside) this git working tree, that
# could wipe committed repo files. Protect them with excludes: a static list of
# known entries PLUS every tracked top-level entry from `git ls-files`.
PROTECT=()
if [ "${MODE}" = "sync" ]; then
  for e in .git .cursor scripts README.md AGENTS.md .gitignore; do
    PROTECT+=(--exclude "/${e}" --exclude "/${e}/**")
  done
  if git -C "${LOCAL_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r entry; do
      [ -n "${entry}" ] || continue
      PROTECT+=(--exclude "/${entry}" --exclude "/${entry}/**")
    done < <(git -C "${LOCAL_DIR}" ls-files | sed 's#/.*##' | sort -u)
  fi
fi

mkdir -p "${LOCAL_DIR}"

echo "Syncing '${SRC}' -> '${LOCAL_DIR}' (scope=${SCOPE}, mode=${MODE})"
rclone "${MODE}" "${SRC}" "${LOCAL_DIR}" --fast-list --drive-acknowledge-abuse "${EXTRA_FLAGS[@]}" "${PROTECT[@]}" "$@"

echo "Done. Files available under: ${LOCAL_DIR}"
echo "--- top-level contents ---"
rclone lsf "${SRC}" "${EXTRA_FLAGS[@]}" 2>/dev/null | head -50 || true
