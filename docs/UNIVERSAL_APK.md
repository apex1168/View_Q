# Universal Android APK — 19 November 2026

Built View Q 1.1.4, base version code 4006, in release mode on GitHub's Linux runner.

| Local download | Size (bytes) | Approximate size |
| --- | ---: | ---: |
| `dist/View-Q-universal.apk` | 45,735,847 | 45.7 MB / 43.6 MiB |
| `dist/View-Q-arm32.apk` (Realme C30) | 23,751,769 | 23.8 MB / 22.7 MiB |
| `dist/View-Q-arm64.apk` | 24,480,845 | 24.5 MB / 23.3 MiB |
| `dist/View-Q-x86_64.apk` | 24,935,483 | 24.9 MB / 23.8 MiB |

The universal release APK is **76.3% smaller** than the previous 192,762,576-byte
debug APK. A compressed debug fallback is also available at 102.3 MiB.

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

- [GitHub release build succeeded](https://github.com/apex1168/View_Q/actions/runs/44547803858) at source commit `11fb65f`.
- Source analysis and all nine Flutter UI tests passed on GitHub.
- Universal and all three processor-specific release builds succeeded.
- Downloaded APK checksums matched the GitHub build's checksum manifest before local signing.
- Android `aapt dump badging` confirmed all three architectures and minimum API 24.
- Android `apksigner verify --verbose` passed for all four locally signed release APKs (v2 and v3 signatures).
- Android `zipalign -c -P 16 4` passed. This checks APK entry alignment, not all runtime compatibility.
- Local SHA-256 checksums are supplied in `dist/SHA256SUMS.txt`.
- No Android device was connected during verification, so installation and launch of this universal APK were not tested.
- No new UI or OCR behavior was changed for this packaging update.

## Release limitation

The local universal release build was blocked by Windows Application Control,
so the release APKs were built by GitHub Actions on Linux. No Windows security
settings were changed. The downloaded APKs were verified and signed locally
using the existing development key. Their certificate SHA-256 matches the
previous APK (`3237ff2f73ed798aa43c3694a5a3c1ba5c8a26e3f68767023fc960b4d5050e5b`),
so compatible existing installations can update without uninstalling. Public
production distribution still requires a stable private production signing key.

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
