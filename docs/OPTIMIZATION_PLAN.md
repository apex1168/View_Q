# View Q optimization rollout

The Android app now saves a 300-pixel WebP preview at quality 70 for new imports. Library cards decode that preview, with the original as a fallback for earlier imports. OCR caps input width at 1280 pixels and releases the bitmap after recognition. Resizing in memory avoids writing a temporary image. The search field waits 150 ms before querying; native worker threads already keep OCR and database work off Flutter's UI thread.

On databases that support the FTS5 trigram tokenizer, Android uses a ranked substring index for queries whose terms all contain at least three characters. Shorter queries and system databases without trigram support search the OCR transcript for literal substrings. The app refreshes active results after imports, deletes, query edits, and changes in indexing counts. OCR text stays intact for the reader; automatic character substitutions could corrupt amounts, URLs and codes.

For a smaller Android APK, build for the phone's CPU architecture with `flutter build apk --release --split-per-abi --no-tree-shake-icons`. The icon flag is needed on this Windows machine because Application Control blocked Flutter's font subset tool. The local release build uses the debug signing key for installation over earlier test APKs.

Android stores categories, summaries, and key facts in SQLite and refreshes them for existing recognized screenshots during the database upgrade. Screenshot details show the summary first, with a separate View full text button for the original transcript. The rules run on native worker threads alongside indexing. OTP messages get a generic summary without extracted codes. Android also compacts SQLite after a deletion when free pages account for at least 4 MiB and 25% of the database.

Remaining changes and acceptance checks:

1. Prototype unbundled ML Kit as an Android build variant. Measure the APK and verify that a sideloaded install can download the OCR model, then read screenshots offline after installation. Keep the current Tesseract build available for devices without Google Play Services and retain iOS OCR.
2. Design gallery references as an explicit storage mode. Verify access after restart and show a missing-original state if the gallery copy is deleted. Support shares from other providers where the source URI may expire. Keep existing private copies through migration. Measure database growth before selecting a compaction schedule; rebuilding SQLite on every deletion can stall writes.
3. Add a portable SQLite build if ranked substring search is required on the Realme and its system SQLite lacks trigram. Test migration, Unicode queries, short terms, punctuation, and deletion. Keep OCR corrections separate from original text.
4. Bring Android's local summaries to iOS and validate their accuracy with a representative screenshot set.
5. Prototype a read-only desktop view started explicitly from the phone, with an expiring pairing code and a stop control. Test access on the same network and verify unauthenticated requests cannot see the library. For user-managed sync, export a versioned portable snapshot of selected text and thumbnails; do not synchronize the live SQLite database or its journal between devices.
