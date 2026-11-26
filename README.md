# View Q

**Find any saved screenshot by the words inside it.**

Save a screenshot of an address, receipt, or chat. When you need it again, search
for a word you remember. View Q reads English text offline and keeps your
screenshots and search data on your device.

[**⬇ Download View Q for Android (.apk)**](https://view-q-android-download.vercel.app/View-Q.apk)

Free and open source · Android 7.0 or newer · No sign-in or ZIP extraction

## Install on Android

1. On your phone, tap the download link above. It downloads one APK for all supported processors.
2. Open **View-Q.apk** from **Downloads**. If Android asks, allow **Install unknown apps** for the app opening the file.
3. Tap **Install**, then **Open**. You can turn the installation permission off afterward.

This is a test build. For an update, install over your existing copy if the signing
keys match. If Android rejects the update, export your library before uninstalling.
Uninstalling deletes saved data. See [build and signing details](docs/UNIVERSAL_APK.md).

## Save and find screenshots

1. Open a screenshot in your gallery, tap **Share**, and choose **View Q**. You can also tap **Save screenshot** inside View Q.
2. Once View Q reads the image, search for a word from the screenshot.
3. Tap a result to see the screenshot and its extracted text.

View Q keeps its own copy, so you can still find a saved screenshot after deleting
the gallery original. Search works offline.

## Back up your library

Open the **⋮** menu in View Q and choose **Export backup**. Save the ZIP somewhere
private. Use **Restore backup** to import it later. Backups contain your images
and text and are not encrypted. App cloud backup is disabled.

## iPhone

The iPhone project requires a Mac and Xcode and has not been built or tested.
See the [iPhone build guide](docs/IPHONE.md).

## Build or contribute

View Q's own code is open source under [Apache 2.0](LICENSE).

- [Windows setup, building and USB testing](docs/WINDOWS.md)
- [Current APK sizes and verification](docs/UNIVERSAL_APK.md)
- [Device testing checklist](docs/TESTING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Third-party licenses](THIRD_PARTY_NOTICES.md)

The shared app is written in Flutter and Dart, with native Android and iOS
integrations, SQLite search, and bundled Tesseract OCR. Very small or unclear
text can be missed; saved original images are preserved.
