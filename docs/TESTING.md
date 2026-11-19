# Verification checklist

Use a disposable screenshot with large English text, such as **Train ticket
London platform 7**. Keep airplane mode on for the actual app tests. Initial
developer-tool downloads require internet.

| Test | Expected result |
| --- | --- |
| Share image from Gallery/Photos, app closed | View Q is an image share target; “Screenshot saved” appears only after saving |
| Share while View Q is already open | One new library item for each image; no duplicate from resuming |
| Tap Save screenshot | System picker; cancelling creates no item or success message |
| Import PNG, JPEG and a very tall screenshot | Image immediately visible with “Reading text…”; opening still works |
| First launch in airplane mode | Bundled English OCR works without any download |
| Search `TRAIN, ticket!` | Same matching item as `train ticket`; snippet contains matching text |
| Search an absent word | “No matching screenshots”; search field stays available |
| Search punctuation or `" OR *` | No crash, no unescaped search operators |
| Open result | Saved image opens; pinch zoom and Back work |
| Force-stop/restart and reboot | Saved copy remains; unfinished OCR resumes when app opens |
| Delete the gallery original | View Q's copy still opens after restart |
| Save an image without text | It remains in library as “No readable text” |
| Force OCR failure in a development build | Image retained; “Try again” requeues it |
| Delete while “Reading text…” | Confirm dialog; image and search text stay gone after OCR finishes/restart |
| Cancel deletion | Nothing removed |
| Set largest system font and display size | Scrollable screens, readable buttons, no clipped text; test landscape and keyboard too |
| TalkBack / VoiceOver | Logical reading order; labeled search, save, open, Back, retry and delete |
| Low storage / expired share URI / invalid image | Clear error; no false success confirmation |
| Interrupt a save or OCR, then reopen | No incomplete item displayed as successfully saved; pending items resume |
| iOS multiple images and background app | Extension completes copies; main app imports once on next foreground |
| Backup inspection | Android no-backup files excluded; iOS root/inbox exclusion resource values true |

Android developer checks (PowerShell, from the workspace):

```powershell
. .\scripts\android-env.ps1
flutter analyze --no-pub
flutter test
Push-Location android
.\gradlew.bat :app:testDebugUnitTest
Pop-Location
```

The Android tests exercise private copies, reopen persistence, word search,
empty OCR, retry, and the delete/late-OCR race through the real LibraryStore using
Robolectric. Flutter tests cover the empty and no-match states, save timing,
picker cancellation, recovery, and large text. Neither test suite substitutes for
native Share sheet, real OCR, device performance, or assistive-technology tests.

For the Realme C30, inspect the device's actual version after connecting:

```powershell
adb devices -l
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell getprop ro.product.cpu.abilist
```

The SDK value must be at least **24**. The debug build includes ARMv7, ARM64 and
x86-64. For font testing, use Settings → Display → Font size; TalkBack is usually
under Settings → Accessibility. Menu wording varies by Realme software version.
