# AGENTS.md

## Cursor Cloud specific instructions

### What this repo does
`cloud-drive` syncs files from Google Drive into the VM (default
`./gdrive-context/`, git-ignored) so they can serve as context for agent tasks.
The mechanism is `scripts/sync_gdrive.sh`, which drives [rclone](https://rclone.org).

### Environment config (source of truth)
`.cursor/environment.json` is committed and its `install` field IS the startup
update script (install rclone + gated Drive sync). Because a committed
`environment.json` takes precedence over any dashboard-saved environment, edit
the sync/startup behavior there. The credential is NOT in this file — it must be
a secret (`GDRIVE_SERVICE_ACCOUNT_JSON`).

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
- **Auto-sync on startup is a hard gate.** The update script runs the sync on
  every VM start, and a failed sync makes the whole environment-setup step fail
  (there is intentionally no `|| true`). So "environment ready" implies "Drive
  content synced". Consequences: if Drive is unreachable, the credential is
  missing/expired, or the folder is no longer shared, the environment will fail
  to come up. To make it non-blocking again, append `|| true` to the sync line
  in the update script.
- Startup defaults (each overridable via a same-named secret/env var):
  `GDRIVE_SHARED_WITH_ME=1`, `GDRIVE_FOLDER=agent 工作区`,
  `GDRIVE_LOCAL_DIR=/workspace`.
- The only startup guard kept is `[ -f scripts/sync_gdrive.sh ]`, so that before
  this PR is merged (script absent on the base branch) startup is not blocked.
  After merge the gate is fully active; the credential must also be stored as a
  **secret** (uploads do not persist) or the gate will fail on missing creds.
- You can also run the sync manually on demand: `./scripts/sync_gdrive.sh`.
- Synced files are git-ignored; never commit user Drive data or credential JSON.
  `.gitignore` ignores everything at the repo root (`/*`) and allowlists only the
  project's own files, because Drive content is synced directly into `/workspace`.
  When adding a new *tracked* file at the repo root, allowlist it in `.gitignore`
  (e.g. `!/newfile`).
- To flatten a folder's contents directly into `/workspace` (no
  `gdrive-context/<folder>/` wrapper), run with `GDRIVE_FOLDER=<folder>` and
  `GDRIVE_LOCAL_DIR="$(pwd)"` (plus `GDRIVE_SHARED_WITH_ME=1` for shared folders).
