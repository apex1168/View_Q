# Build View Q for iPhone (Mac required)

The iOS project and Share extension are implemented but have **not been compiled
or tested on a Mac**. Windows cannot build an iPhone app. Plan for a Mac validation
pass before relying on this build or distributing it.

1. On a Mac, install Flutter **3.50.0**, Xcode, and its iOS platform tools. Open
   Xcode once to complete its setup. Run `flutter doctor` and resolve iOS errors.
2. Copy this source folder to the Mac, excluding `.tools`, `build`, `.dart_tool`,
   and `android/local.properties` (these contain Windows-specific caches).
3. In Terminal, enter the project folder and run:

   ```sh
   flutter pub get
   flutter build ios --config-only --no-codesign
   open ios/Runner.xcworkspace
   ```

4. In Xcode, select the **Runner** project. For **Runner** and **ViewQShare**,
   open **Signing & Capabilities**, select your Apple development team, and enable
   automatic signing. The extension is already embedded in Runner.
5. Replace `org.viewq.viewq` with a unique bundle identifier you control, and
   `org.viewq.viewq.Share` with that identifier plus `.Share`. Both targets need
   the **same App Group**. Create your own group, such as
   `group.com.yourname.viewq`, then set it in all four places:
   - `ios/Runner/Runner.entitlements`
   - `ios/ShareExtension/ShareExtension.entitlements`
   - `ViewQAppGroup` in `ios/Runner/Info.plist`
   - `ViewQAppGroup` in `ios/ShareExtension/Info.plist`

   App Groups require appropriate Apple provisioning support. If your account
   cannot provision this capability, use an eligible Apple Developer team. Do not
   remove the entitlement: it is what makes sharing reliable.
6. Xcode resolves the pinned `libtesseract` 0.2.0 Swift package. The Runner target
   links SQLite, zlib, and C++. `assets/tessdata` is already a folder resource in
   Runner. Confirm `eng.traineddata` exists inside the built app's `tessdata`
   folder. There is no CocoaPods dependency to install for this app.
7. Choose **Runner**, select an iPhone or iOS simulator, and press Run. Minimum
   iOS version is **15.0**, for both targets. A physical iPhone must trust your Mac
   and may require Developer Mode under Settings → Privacy & Security.

For an unsigned simulator build:

```sh
flutter build ios --simulator --debug
```

Then run the [device test checklist](TESTING.md), especially Photos → Share →
View Q → “Screenshot saved” → Done. The extension does not force-open the app.
Open View Q yourself; saved images should import and start OCR. Test both a cold
launch and returning to an already-running app. First-use OCR must work in
airplane mode. Test HEIC, PNG, JPEG, multiple shares, VoiceOver, and Larger Text.

Background processing is opportunistic. iOS can defer or skip it. Keeping View Q
open processes the durable queue; reopening resumes unfinished images. The Share
extension copies images only and never runs OCR within its short lifetime.

Before App Store distribution, verify the selected Tesseract binary supports
your Xcode/device architectures and distribution requirements, inspect native
license notices and privacy manifests, and archive both signed targets. No iOS
distribution or App Store validation was performed on Windows.
