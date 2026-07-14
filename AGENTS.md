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
- A folder *shared with* a service account appears under its **"Shared with me"**,
  NOT its Drive root — so a plain `./scripts/sync_gdrive.sh` returns 0 files.
  Run `GDRIVE_SHARED_WITH_ME=1 ./scripts/sync_gdrive.sh` in that case (verified:
  syncs the shared `平台产品周会` folder into `gdrive-context/`).
- **Auto-sync on startup:** the update script runs the sync automatically after
  each VM start, but only when it is safe: it requires `scripts/sync_gdrive.sh`
  to exist AND a credential env var (`GDRIVE_SERVICE_ACCOUNT_JSON` or
  `RCLONE_GDRIVE_TOKEN`) to be set, and it is non-fatal (`|| true`) so it can
  never break pod startup. Defaults used on startup: `GDRIVE_SHARED_WITH_ME=1`,
  `GDRIVE_FOLDER=平台产品周会`, `GDRIVE_LOCAL_DIR=/workspace` (each overridable
  via a same-named secret/env var). For auto-sync to work, the credential must
  be stored as a **secret** (uploads do not persist) and this PR must be merged
  so the script exists on the base branch.
- You can also run the sync manually on demand: `./scripts/sync_gdrive.sh`.
- Synced files are git-ignored; never commit user Drive data or credential JSON.
  `.gitignore` ignores everything at the repo root (`/*`) and allowlists only the
  project's own files, because Drive content is synced directly into `/workspace`.
  When adding a new *tracked* file at the repo root, allowlist it in `.gitignore`
  (e.g. `!/newfile`).
- To flatten a folder's contents directly into `/workspace` (no
  `gdrive-context/<folder>/` wrapper), run with `GDRIVE_FOLDER=<folder>` and
  `GDRIVE_LOCAL_DIR="$(pwd)"` (plus `GDRIVE_SHARED_WITH_ME=1` for shared folders).
