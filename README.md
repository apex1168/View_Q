# View Q

Save a screenshot. Find it later by the words inside it.

View Q is a Flutter app for **Android 7.0+ (API 24)** and **iOS 15+**. It saves
private copies, reads English text locally with bundled Tesseract data, and
searches with SQLite full-text search. No account, cloud service or internet is
needed after installation. View Q's code is Apache-2.0.

**Start here:** [what was verified](docs/BUILD_REPORT.md),
[iPhone/Mac instructions](docs/IPHONE.md), [device tests](docs/TESTING.md).

## On this Windows computer

Flutter and Android build tools were downloaded into `.tools` in this workspace.
Open PowerShell in this folder, then run:

```powershell
cd 'C:\Users\Administrator\Documents\View Q'
. .\scripts\android-env.ps1
flutter pub get
flutter analyze
flutter build apk --debug
```

The first line with two dots loads the local tool paths for this PowerShell
window. If PowerShell blocks scripts, use the full tool paths or review your
organization's script policy; the app does not require changing security policy.
The debug build succeeded. Its APK is at
`build\app\outputs\flutter-apk\app-debug.apk` (about 173 MiB).

## Back up your Android library

In View Q, open the **⋮** menu and choose **Export backup**. Select a private
folder for the ZIP. It contains your original screenshots, searchable text and
Favorites in an unencrypted file.

To recover your library on Android, choose **Restore backup** from the same
menu and select the ZIP. Restore adds missing screenshots and keeps the versions
already on the phone. Confirm that the ZIP is saved somewhere you can access
before uninstalling View Q or resetting the phone.

## Connect your Realme C30

1. On the phone, open **Settings → About phone** to check the Android version.
   View Q requires Android **7.0 or newer**. The actual phone version was not
   detected because ADB found no connected Android device during setup.
2. Tap **Build number** seven times (it may be under Version). Enter your screen
   lock if asked. This unlocks Developer options.
3. Open Developer options, usually under System or Additional settings. Turn on
   **USB debugging**.
4. Connect a USB **data** cable. Unlock the phone and accept “Allow USB debugging”
   for your own computer. If nothing appears, try File transfer USB mode or a
   different cable/port. Windows may need the phone manufacturer's USB driver.
5. In the same PowerShell window:

   ```powershell
   adb devices -l
   adb shell getprop ro.build.version.release
   adb install -r '.\build\app\outputs\flutter-apk\app-debug.apk'
   ```

   `device` means ready; `unauthorized` means accept the prompt on the phone.
   A blank device list means Windows cannot see a debug connection yet.

Open a screenshot in Gallery → Share → View Q. Wait for **Screenshot saved**.
You can also open View Q and tap **Save screenshot**. Search after “Reading
text…” finishes. Try the device checklist before saving anything important.

## A fresh Windows computer

Install [Flutter 3.50.0](https://docs.flutter.dev/install) and
[Android Studio](https://developer.android.com/studio). In Android Studio's SDK
Manager install Android SDK Platform 36, Build Tools 36, Platform Tools, and
Android SDK Command-line Tools. Flutter uses NDK 28.2.13676358 and may download it
on the first build. Use Java 21 (Android Studio's bundled JDK may satisfy this).
Add Flutter's `bin` folder to PATH, then open a new PowerShell window:

```powershell
flutter doctor
flutter doctor --android-licenses
flutter pub get
flutter build apk --debug
```

Read and accept the SDK licenses if you agree. Ignore Windows desktop/Visual
Studio requirements when building only Android. Dependency downloads need
internet and several GB of disk space. The installed app works offline.

## Project map

- `lib/`: shared Flutter screens and native API contract
- `android/`: image-share receiver, private storage, FTS4 and WorkManager OCR
- `ios/Runner/`: photo picker, library, FTS4 and background OCR
- `ios/ShareExtension/`: native image Share extension
- `assets/tessdata/`: bundled English OCR model
- `licenses/`, [third-party notices](THIRD_PARTY_NOTICES.md)
- [architecture and limits](docs/ARCHITECTURE.md)

Saved copies remain after deleting gallery originals. Uninstalling View Q deletes
its library. App backup/cloud sync is deliberately disabled. Very long images
are downsampled for OCR, so tiny text can be missed; originals are preserved.
