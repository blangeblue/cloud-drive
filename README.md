# cloud-drive

Sync files from **Google Drive** into the local VM so they can be used as
context for agent tasks.

Uses [rclone](https://rclone.org) with an environment-variable-only remote, so
no interactive `rclone config` / browser login is needed inside the VM.

## Quick start

1. Provide credentials (see below) as environment variables / secrets.
2. Run the sync:

   ```bash
   ./scripts/sync_gdrive.sh
   ```

   Files are downloaded to `./gdrive-context/` by default (git-ignored).

## Credentials (choose one)

### Method A — Service account (recommended for automation)

1. In [Google Cloud Console](https://console.cloud.google.com/), create a
   project, enable the **Google Drive API**, create a **service account**, and
   download its **JSON key**.
2. Share the Drive folder(s) you want to sync with the service account's email
   (e.g. `name@project.iam.gserviceaccount.com`), or put them on a Shared Drive
   the account can access.
3. Set the JSON key content as `GDRIVE_SERVICE_ACCOUNT_JSON`.

### Method B — OAuth token from your own machine

1. On a machine with a browser, run `rclone config` and create a `drive` remote.
2. Run `rclone config show <remote>` and copy the `token` value.
3. Set it as `RCLONE_GDRIVE_TOKEN` (optionally also `GDRIVE_CLIENT_ID` /
   `GDRIVE_CLIENT_SECRET` if you used your own OAuth client).

## Configuration (optional)

| Variable                | Default            | Description                                                    |
| ----------------------- | ------------------ | ------------------------------------------------------------- |
| `GDRIVE_FOLDER`         | *(root)*           | Drive folder path or folder ID to sync.                       |
| `GDRIVE_LOCAL_DIR`      | `./gdrive-context` | Local target directory.                                       |
| `GDRIVE_SCOPE`          | `drive.readonly`   | rclone drive scope (use `drive` for R/W).                     |
| `GDRIVE_SHARED_WITH_ME` | *(unset)*          | Set to `1` to sync from "Shared with me" (see note below).    |

> **Service account + shared folder:** when you *share* a Drive folder with a
> service account, it lands in the account's **"Shared with me"**, not its own
> Drive root. Run with `GDRIVE_SHARED_WITH_ME=1` so the sync can see it, e.g.:
>
> ```bash
> GDRIVE_SHARED_WITH_ME=1 ./scripts/sync_gdrive.sh
> ```

Extra arguments are passed through to `rclone copy`, e.g.:

```bash
./scripts/sync_gdrive.sh --dry-run
```
