# How View Q stores and reads screenshots

Flutter owns the screens, navigation, accessibility semantics and platform
channel contract (`org.viewq/library`). Kotlin and Swift own native image access,
private storage, SQLite FTS4, and the durable OCR queue. No image bytes travel
through the platform channel. All database and OCR work runs off the UI thread.

## Durable saves

Android receives SEND/SEND_MULTIPLE and copies each URI while the activity still
has its grant. The system Photo Picker is used when available, with AndroidX's
document-picker fallback on older devices. No broad photo/storage permission is
requested. Saves stream to `.part`, flush to disk, validate image headers, rename
to `.img`, then insert a pending database row. Confirmation follows that insert.
Activity recreation does not deliberately replay an already-consumed intent.

iOS PHPicker and the Share extension call `loadFileRepresentation`. The temporary
file is copied **inside** that callback, flushed, and atomically renamed within
an App Group inbox. The extension confirms only completed copies. Runner imports
ready files with the same UUID, inserts the database row, then removes the inbox
copy. A crash between insertion and cleanup is idempotent. Paths stored in the
database are relative, so iOS container relocation does not break them.

Each image is a separate import. Sharing the same picture twice deliberately
creates two saved copies. Batch shares report per-image failures; successfully
copied items remain saved.

## OCR and search

`pending`, `done`, `failed`, and `deleted` are durable SQLite states. A single OCR
runner processes pending rows in creation order. Pending rows remain pending
until a successful/failed result commits, so process death does not strand work
in a permanent “running” state. Android uses a foreground executor plus WorkManager
with a shared process lock. iOS uses a serial queue and BGProcessingTask. Neither
platform depends on immediate background scheduling.

Tesseract runs with English `tessdata_best` bundled in the app. Android reads
long screenshots in overlapping image regions, uses page layout detection and
tries sparse or contrast-adjusted recognition where confidence is low.
Processing is serial and originals remain untouched. iOS retains the bounded
single-image OCR pipeline. A screenshot remains visible after an empty read.

Search splits punctuation and whitespace into up to 16 literal terms. Android
uses ranked trigram matching when available and a literal substring scan
otherwise. When no exact matches exist, Android can recover a single OCR or
typing error per eligible word in a bounded set of recent screenshots. Numbers
must still match literally. The Search tab shows recently opened search results
when its query is empty; Library continues to show every undeleted screenshot.

The gallery receives metadata and snippets from the preview channel. It loads
the full transcript by screenshot ID when a card opens. Android indexes the
library sort order and pending OCR jobs so these reads do not have to sort the
whole table.

Text corrections are local and replace the transcript, search index, and
Android summary in one transaction. An OCR result can only write to a pending
row, so an earlier background job cannot replace a completed correction.

Whitespace between quoted tokens works with both standard and enhanced FTS4
parsers; see [SQLite's query syntax documentation](https://www.sqlite.org/fts3.html#full_text_index_queries).

## Deletion and interruption

Deletion commits a tombstone and removes the FTS entry in one transaction. It
then removes the file and row. OCR completion updates only an existing pending
row, and only creates an index entry when that update succeeds, in the same
transaction. A late OCR result cannot recreate a deleted row or its text.
Tombstoned files are cleaned again on reopening if an earlier removal failed.
Android also removes unreferenced files older than 24 hours left by interrupted
saves; live/recent copies are not swept.

## Privacy and limits

Android images, SQLite and OCR data live under `noBackupFilesDir`. Backup and
device-transfer exclusions are configured. iOS marks both App Group inbox and
Application Support/ViewQ excluded from backup. No iCloud container or cloud
sync is configured. Uninstalling the app removes its library; there is no recovery
or export feature in this version. The original gallery's own cloud-sync settings
are outside View Q's control.

No accounts, backend, network client, analytics or external OCR service exists in
the app. Flutter's debug/profile manifests include INTERNET for development
debugging; the main release manifest does not. Build-time SDK/dependency downloads
require internet, installed OCR does not.

Images larger than 100 MB and undecodable files are rejected with an error.
Thumbnails and detail decoding are bounded. The current library API returns all
metadata rather than paging; very large libraries need profiling and pagination
before scaling to many thousands of screenshots.
