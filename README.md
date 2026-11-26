# View Q

**Find saved screenshots by the words inside them.**

## [Download for Android](https://view-q-android-download.vercel.app/View-Q.apk)

**Android 7.0 or newer · No sign-in · No ZIP**

1. Tap **Download for Android** on your phone.
2. Open **View-Q.apk** from **Downloads** and tap **Install**. If prompted, allow **Install unknown apps** for the app opening the file.

This is a test build. If Android rejects an update, export your library before
uninstalling. Uninstalling deletes saved data. See [build and signing details](docs/UNIVERSAL_APK.md).

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
