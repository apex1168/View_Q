# View Q

**Save a screenshot. Find it later by the words inside it.**

View Q is a private screenshot library with offline English text recognition
and search. No account, cloud service or internet connection is needed to use it.

## Download for Android

[Download the Android APKs](https://github.com/apex1168/View_Q/actions/runs/44547803858)

1. Open the link above and sign in to GitHub if asked.
2. Under **Artifacts**, download **View-Q-Android-APKs** and unzip the file.
3. Choose an APK from the table below.

| APK | Choose this for | Approximate download |
| --- | --- | ---: |
| `View-Q-universal.apk` | One file for all supported processors | 46 MB |
| `View-Q-arm32.apk` | Realme C30 and other 32-bit ARM phones | 24 MB |
| `View-Q-arm64.apk` | 64-bit ARM phones | 25 MB |
| `View-Q-x86_64.apk` | Devices with x86-64 processors | 25 MB |

Requires **Android 7.0 or newer**. If you are unsure which processor your phone
uses, choose the universal APK. Older Android versions and 32-bit Intel devices
are not supported.

## Install on Android

1. Open the APK on your phone from **Files** or **Downloads**.
2. If prompted, allow **Install unknown apps** for the app opening the file.
3. Tap **Install**, then **Open**. You can turn the installation permission off afterward.

**You do not need a computer, USB debugging, or Developer options.**

These are testing builds. To update, install over the existing app when its
signing key matches. If Android rejects an update, keep the existing app and
export your library before taking further steps. Uninstalling deletes saved data.
See [build and signing details](docs/UNIVERSAL_APK.md).

## Save and find screenshots

- In your gallery, open a screenshot, tap **Share**, and choose **View Q**.
- Or open View Q and tap **Save screenshot** to choose an image.
- After the text is read, search for a word from the screenshot.
- Open a result to view the image, its summary, and the full extracted text.

View Q keeps its own copy, so saved images remain available if you delete the
gallery originals. Screenshots and recognized text stay on your device.

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
