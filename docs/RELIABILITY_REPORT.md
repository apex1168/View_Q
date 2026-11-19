# Reliability update — 19 November 2026

## Verified improvements

- Android and iOS OCR attempts carry a generation number. A result must match the pending generation before it can commit. Edits advance the generation.
- Existing text remains searchable while a screenshot is being re-read.
- Android tests cover the sequence of an old job, a correction, and another re-read, as well as deletion, restoration, and failed recognition.
- Android gallery requests apply category, date, and selected-ID filters before returning pages of 60 cards. More cards load on demand.
- The text editor asks before discarding unsaved edits.
- Categories can be corrected manually or returned to Automatic. Android retains overrides through re-reading and backup/restore.
- OCR cancellation is checked between image regions and before recognition. WorkManager keeps one unique pending request instead of appending a chain on every resume.
- The SQLite trigram capability check executes an actual query. The on-device benchmark found that checking the schema alone could select an unavailable FTS5 module on the Realme.
- App version is now 1.1.0, build 2.

## Realme C30 benchmark

The instrumentation test generates its own images in isolated cache storage. It does not read the user's saved screenshots. The target is the connected RMX3581 running Android 11, using the test/debug build.

| Generated fixture | OCR time | Expected-word recall | Reference found | Search query time |
| --- | ---: | ---: | --- | ---: |
| Light receipt | 1.526 s | 100% | Yes | 3.010 ms |
| Dark message | 2.535 s | 100% | Yes | 2.243 ms |
| Tall 720 × 4800 capture | 3.875 s | 100% | Yes | 1.957 ms |
| Small 20 px text | 3.815 s | 100% | Yes | 2.582 ms |

Raw transcripts and timings are in ocr-benchmark-realme-c30.json.

Expected-word recall checks whether each expected word appears in the output. It does not penalize extra words, ordering errors, or all character differences. These four synthetic fixtures establish a repeatable smoke benchmark. They do not establish accuracy on real screenshots, mixed languages, arbitrary fonts, photos, or large-library performance. Search timings cover this small fixture library and exclude the Flutter debounce and rendering.

## Remaining validation and work

The final update passed 13 Android database/backup tests, nine Flutter UI tests,
and Flutter static analysis. The instrumentation test passed all four generated
OCR fixtures on the Realme C30. The temporary instrumentation package is removed
after validation and the phone is returned to the release APK.

iOS source includes generation protection and manual categories, but has not been compiled or run on a Mac. Android's literal substring fallback still scans text when trigram is unavailable, and approximate search still has bounded coverage of recent records. The iOS gallery fallback still fetches all metadata before slicing pages.

Real screenshot accuracy, large-library latency, sustained memory/battery measurements, and frame profiling remain necessary. Summaries remain rule-based extracts. Duplicate detection, draft recovery after process death, undo for deletion, encrypted/cancellable backups, and Android/iOS feature parity remain open.

The local release continues to use the existing debug signing key so it can update the installed test app. Public distribution needs a managed release key and distribution validation.
