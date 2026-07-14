# AGENTS.md

## Cursor Cloud specific instructions

### What this repo does
`cloud-drive` syncs files from Google Drive into the VM (default
`./gdrive-context/`, git-ignored) so they can serve as context for agent tasks.
The mechanism is `scripts/sync_gdrive.sh`, which drives [rclone](https://rclone.org).

### Running the sync
- `rclone` is required; the update script installs it if missing.
- Configure the remote via env vars only (no interactive `rclone config` needed).
  Provide **one** credential set as a secret:
  - `GDRIVE_SERVICE_ACCOUNT_JSON` — service account key JSON (recommended for
    headless automation). The target Drive folder(s) must be **shared with the
    service account's email**, otherwise it sees nothing.
  - or `RCLONE_GDRIVE_TOKEN` (+ optional `GDRIVE_CLIENT_ID` /
    `GDRIVE_CLIENT_SECRET`) — an OAuth token generated with `rclone config` on a
    machine that has a browser.
- Then run `./scripts/sync_gdrive.sh`. See `README.md` for `GDRIVE_FOLDER`,
  `GDRIVE_LOCAL_DIR`, and `GDRIVE_SCOPE`.

### Gotchas
- A service account has **no access to a user's personal Drive** unless the
  files/folders are explicitly shared with it (or live on an accessible Shared
  Drive). Sharing a folder is the usual fix when a sync returns 0 files.
- The sync is a network fetch and is intentionally kept **out of the update
  script** — run it on demand.
- Synced files land in `gdrive-context/` which is git-ignored; never commit
  user Drive data or credential JSON.
