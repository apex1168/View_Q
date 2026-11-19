# View Q build report — 17 November 2026

## What is ready

The Android debug APK built successfully:

`C:\Users\Administrator\Documents\View Q\build\app\outputs\flutter-apk\app-debug.apk`

Size: 181,495,192 bytes (about 173 MiB). This is a universal **debug** build with
three CPU architectures and debugging support; it is not a store release.

SHA-256:
`cda9030523f5bb56303582974ab57d08a6ddb020bf9f621a0108b8896d7f4ee8`

The workspace includes Flutter screens, Android share handling and system picker,
private image copies, SQLite FTS4 search, bundled English Tesseract OCR, durable
pending work, retry and deletion, Android WorkManager, iOS background processing,
and the native iOS Share extension with App Group handoff. Original code uses
Apache-2.0; third-party license texts are included.

## Checks completed

| Check | Result |
| --- | --- |
| Flutter static analysis | Passed; no issues found |
| Flutter widget tests | 7 passed |
| Home accessibility guidelines | Contrast, touch-target size, and labels passed automated checks |
| Large text | Home and detail/confirmation tested at 250% scale in a 360 × 640 test viewport |
| Android debug compilation and packaging | Passed |
| APK manifest | View Q label, API 24 minimum, API 36 target, image SEND/SEND_MULTIPLE verified |
| APK privacy configuration | allowBackup=false, fullBackupContent=false, data-extraction exclusions verified |
| APK offline assets | English model (4,113,088 bytes), native Tesseract for ARMv7/ARM64/x86-64, license assets verified |
| iOS project structure | Parsed successfully; Share extension embedded, target dependency, signing files and sources checked |
| Android storage/search unit tests | 4 passed using Robolectric's Android API 28 runtime |
| Connected Android device | None found by ADB on the retry |

Widget tests cover the empty-library guidance, no matching results, confirmation
only after native save success, picker cancellation, storage-error recovery,
large text, accessibility guidelines, and cancellation of the delete dialog.
The previous Windows block on the Flutter test runner did not recur on retry.

The native Android tests verify that private copies survive deleting the source
and reopening the database, case-insensitive words and punctuation work, no-text
images remain visible, failed OCR can be retried, and a late OCR result cannot
restore a deleted image. They exposed issues in older-Android database cleanup,
a result-returning SQLite configuration statement, and explicit FTS AND syntax;
those issues were fixed and all four tests rerun successfully.

## Not verified on hardware

No Realme C30, Android emulator, Mac, iPhone or iOS simulator was available.
Therefore actual share-sheet behavior, native OCR recognition quality, phone
restart persistence, deleting gallery originals, background scheduling,
TalkBack/VoiceOver behavior, and performance on the Realme C30 remain to be
checked with [the device checklist](TESTING.md). Automated tests do not establish
that these device flows work.

The iPhone project **has not been compiled or run**. It needs a Mac with Xcode,
compatible signing/App Group provisioning, dependency resolution, and the Photos
sharing tests in [IPHONE.md](IPHONE.md). Do not treat structural validation as an
iPhone build result.

## Compatibility and toolchain

- Android **7.0+**, API **24** minimum; compiled/targeted against API **36**.
- iPhone/iPad **iOS 15.0+** chosen for both the app and extension.
- Flutter **3.50.0**, Dart **3.14.0**, Java **21.0.13**, Gradle **9.5.0**,
  Android Gradle plugin **9.3.1**, Android Build Tools **36.0.0**,
  NDK **28.2.13676358**.
- Tesseract4Android **4.9.0**; English tessdata_fast **4.1.0** bundled.
- iOS binary dependency: libtesseract **0.2.0**, pinned through Swift Package Manager.

No actual Android version can be stated for your phone until it is connected.
Check Settings → About phone → Android version, or use the ADB commands in the
README. An Android version of 7.0 or newer meets the app's OS requirement.

Flutter doctor warns that the local SDK path contains a space (`View Q`). The
debug build nevertheless succeeded. For a permanent SDK installation use a path
without spaces, such as `C:\Android\Sdk`. The current pinned build also emits
legacy Kotlin/Gradle API warnings; a future Flutter/AGP upgrade will need that
configuration migrated. Neither warning prevented this APK build.

The app preserves originals but downsamples very large images for OCR and preview
memory safety. Tiny text in long screenshots can be missed. Background OCR is
best-effort; opening View Q resumes pending work. Uninstalling removes the library.

