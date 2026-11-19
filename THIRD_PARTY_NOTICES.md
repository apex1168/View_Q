# Third-party components

View Q's code is Apache-2.0 (LICENSE). The following components keep their
original licenses. Build tools in `.tools/` are not part of the app or source release.

| Component | Version / source | License |
| --- | --- | --- |
| Flutter and Dart runtime | Flutter 3.50.0 / Dart 3.14.0 | BSD-3-Clause; engine notices include additional dependencies |
| Material UI | 1.1.0, pub.dev | BSD-3-Clause |
| Archivo Black wordmark font | Google Fonts, ofl/archivoblack | SIL Open Font License 1.1; bundled in licenses/ArchivoBlack-OFL.txt |
| Cupertino UI and Dart packages | Exact versions in pubspec.lock | See bundled per-package licenses |
| Tesseract4Android | 4.9.0, adaptech-cz/Tesseract4Android | Apache-2.0 |
| Android Tesseract | 5.5.1, included by Tesseract4Android | Apache-2.0 |
| English language model | tessdata_best tag 4.1.0, eng.traineddata | Apache-2.0 |
| iOS libtesseract XCFramework | SwiftyTesseract/libtesseract 0.2.0, pinned Swift package | MIT packaging; Apache-2.0 Tesseract; Leptonica BSD-style; dependency notices supplied upstream |
| Leptonica | 1.85.0 in Android OCR; version supplied by iOS binary | BSD-2-Clause-style |
| libpng | 1.6.48 in Android OCR; version supplied by iOS binary | libpng license |
| libjpeg | v9f in Android OCR; version supplied by iOS binary | Independent JPEG Group license |
| AndroidX Activity and WorkManager | 1.10.1 / 2.10.1 | Apache-2.0 |
| SQLite | Platform-provided on Android / iOS | Public domain |

`licenses/` ships in the Flutter asset bundle, including Dart package license
texts collected from resolved packages. Flutter also builds its standard
NOTICES.Z asset. Native dependency notices are retained here. Test dependencies
are not linked into the release app.

The iOS app calls the Tesseract C API directly. It does not incorporate the
SwiftyTesseract Swift wrapper. Its binary supplier is the SwiftyTesseract project.
The SPM manifest verifies the XCFramework SHA-256 before use.

Bundled English model SHA-256 is recorded in `assets/tessdata/SHA256SUMS`.
Builds need package downloads; installed applications never download OCR models.

Sources:
- https://github.com/adaptech-cz/Tesseract4Android/tree/4.9.0
- https://github.com/SwiftyTesseract/libtesseract/tree/0.2.0
- https://github.com/tesseract-ocr/tessdata_best/tree/4.1.0
- https://github.com/tesseract-ocr/tesseract
- https://github.com/DanBloomberg/leptonica
- https://www.sqlite.org/copyright.html
