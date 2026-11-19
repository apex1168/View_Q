# Windows developer guide

These steps are for building View Q from source or testing it through USB.
To install a downloaded APK, use the [installation steps in the README](../README.md#install-on-android).

## Build in the existing workspace

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
The debug APK is written to
`build\app\outputs\flutter-apk\app-debug.apk`.

## Connect your Realme C30

1. On the phone, open **Settings → About phone** to check the Android version.
   View Q requires Android **7.0 or newer**. The connected Realme C30 was
   identified as Android **11**, with a 32-bit ARM processor environment.
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

## Build a universal APK

Run `./scripts/build-universal.ps1` from the project folder in PowerShell.
The output is `dist/View-Q-universal.apk`. To build the larger debug fallback,
run `./scripts/build-universal.ps1 -DebugBuild`.

On this Windows computer, Application Control currently blocks Flutter's
release compiler. The smaller release APKs were successfully built on Linux
with [GitHub Actions](https://github.com/apex1168/View_Q/actions/workflows/android-apk.yml).
No Windows security settings need to be disabled.

See [APK sizes, signing details and verification](UNIVERSAL_APK.md) for the
current build. Use a stable private production signing key before a public
production launch. The current builds use development signing.
