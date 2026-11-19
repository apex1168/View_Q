# Universal Android APK — 19 November 2026

Built View Q 1.1.4, version code 4006, as one installable APK:

`dist/View-Q-universal-debug.apk` — 107,306,308 bytes (102.3 MiB),
down from 183.8 MiB: **44.3% smaller**.

Native libraries are now compressed inside the APK. The offline OCR model and
all three processor architectures are retained. Android extracts the selected
architecture's libraries during installation; this reduces download size, not
the app's installed library size.

## Compatibility

- Android 7.0 and newer (minimum API 24, target API 36).
- ARM 32-bit (`armeabi-v7a`), ARM 64-bit (`arm64-v8a`), and Intel/AMD 64-bit (`x86_64`).
- The packaged APK contains Flutter and Tesseract native libraries for each architecture.
- Older Android releases and 32-bit Intel devices are not supported.
- A universal APK supports these configurations; this is not a claim that every device has been tested.

## Verification

- Universal debug build completed successfully.
- Android `aapt dump badging` confirmed all three architectures and minimum API 24.
- Android `apksigner verify --verbose` passed (APK Signature Scheme v2).
- Android `zipalign -c -P 16 4` passed. This checks APK entry alignment, not all runtime compatibility.
- SHA-256 checksum is supplied beside the APK.
- No Android device was connected during verification, so installation and launch of this universal APK were not tested.
- No new UI or OCR behavior was changed for this packaging update.

## Release limitation

The universal release build failed because Windows Application Control blocked
Flutter's `gen_snapshot.exe` for all three architectures. No security settings
were changed. The delivered file is a development/debug build, which is larger
and is intended for testing rather than a production launch. It retains the
existing development signing key so compatible existing installations can update
without uninstalling. A public production release still requires a successful
release build and a private production signing key.

## Build and share

In PowerShell, from the project folder:

```powershell
.\scripts\build-universal.ps1 -DebugBuild
```

On a computer where the release compiler is permitted, omit `-DebugBuild` to
produce the smaller release-mode `dist/View-Q-universal.apk`.

The `Android APKs` GitHub Actions workflow builds release-mode APKs on Linux,
checks the source and UI tests, then uploads a universal APK and three smaller
processor-specific APKs as a downloadable workflow artifact. These artifacts
currently use the build machine's development signing key. They are testing
packages; they are not signed with the Windows machine's key and cannot update
its existing installations directly. A production launch needs a stable private
release signing key.

Send the APK to the other phone. Open it, allow **Install unknown apps** for
the app opening the file if prompted, and tap **Install**. USB debugging is
not needed. Updating an existing installation preserves the library when its
signature matches. Do not uninstall first: uninstalling removes saved data.
