# Backups

## What it does

The backups screen lets the user protect and reset their data:

- **Save a backup** — export the SQLite database to a `.moneybak` file at a chosen location.
- **Restore a backup** — overwrite the current database from a picked file.
- **Delete all data** — wipe every table (after confirmation).

## Mechanics

All logic is in [backups.dart](../../lib/views/backups/backups.dart):

- `saveBackup(context)` — reads the app-documents `db.sqlite` and offers it via
  `FilePicker.saveFile`, with a timestamped `backup-<...>.moneybak` filename
  ([:17-30](../../lib/views/backups/backups.dart#L17-L30)).
- `restoreBackup(context)` — picks a file and overwrites `db.sqlite`, then emits a synthetic
  account `change` event so the UI refetches
  ([:32-40](../../lib/views/backups/backups.dart#L32-L40)).
- `openDeleteDataConfirmationDialog(context)` — confirms via `UtilsService.confirm`, then calls
  `DatabaseService.deleteAllData()` and navigates back to `/`
  ([:42-49](../../lib/views/backups/backups.dart#L42-L49)).

`DatabaseService.deleteAllData()` clears every repository's table —
[database.service.dart:69-74](../../lib/services/database.service.dart#L69-L74).

## Edge cases

- **Restore refresh trick** — after overwriting the DB file, the code emits a fake
  `TableUpdateEvent<Account>` on the accounts repository to trigger the normal event-driven
  refresh, since the underlying file changed out from under the app.
- **Destructive actions confirm first** — delete-all requires confirmation and warns that it is
  irreversible, recommending a backup.
- The backup is the raw SQLite file, so a restore is only compatible with a schema the current
  app version understands (migrations run on next startup).
