# ReviewTrace verification — 2026-07-21

This record separates compile/test evidence from UI, media, and release evidence.

## Toolchain

- macOS 26.5.2
- Xcode 26.6 (17F113)
- iOS SDK 26.5
- Project: `OpenAi_ReviewTrace.xcodeproj`
- Scheme: `ReviewTrace`

## Passed

### Generic iOS compile

- Configuration: Debug
- Destination: `generic/platform=iOS`
- Signing: disabled for this compile check
- Result: passed

### Simulator XCTest

- Device: iPhone 17 Pro Simulator
- OS: iOS 26.5
- Result: 28 passed, 0 failed, 0 skipped
- Latest result bundle during this implementation run: `/tmp/ReviewTrace-Submission-Tests/Logs/Test/Test-ReviewTrace-2026.07.21_09-55-28-+0900.xcresult`

### English/Korean String Catalog UI smoke check

- The app was installed and launched on the dedicated iPhone 17 Pro Simulator.
- Settings changed the app display language from English to Korean and back to English through the actual language picker.
- Home and Settings headings, privacy text, buttons, tab labels, and the per-review spoken-language helper changed immediately from `Localizable.xcstrings`.
- The spoken-review selector remained an independent `한국어 (ko-KR) / English (en-US)` choice.
- `Localizable.xcstrings` contains 194 source keys with 194 Korean localizations; static source lookup found 177 referenced keys and 0 missing keys.
- `InfoPlist.xcstrings` compiled English and Korean purpose strings for Photo Library read/add and Speech Recognition permissions.
- These checks prove String Catalog compilation, layout, and persistence wiring on Simulator, not a real Apple Speech transcription result.

### Prebuilt Simulator judge artifact

- `Scripts/package-simulator-app.sh` completed a Release build for `generic/platform=iOS Simulator` with signing disabled.
- The packaged executable contains both `arm64` and `x86_64` Simulator slices.
- Local release asset: `dist/ReviewTrace-Simulator.app.zip` (1.5 MB; ignored by Git until uploaded as a GitHub Release asset).
- SHA-256: `a852e4bba976cec2b1bb86940bc49b31d3729b45e151e6ed1bc10fe08cded0fe`
- `shasum -a 256 -c` passed.
- A fresh extraction installed and launched successfully on the dedicated iPhone 17 Pro Simulator.
- This proves that the no-rebuild Simulator artifact is installable; it is not physical-device or real-media proof.

### Physical iPhone build, install, launch, and XCTest

- Device class: iPhone 15 Pro
- OS: iOS 26.5.2
- Developer Mode: enabled
- Signed Debug build: passed
- Install: passed; no prior app with `woozyLAB.ReviewTrace` was present
- Launch request: passed; the ReviewTrace process remained listed after launch
- XCTest: 22 passed, 0 failed
- Result bundle: `/tmp/OpenAiReviewTrace-DeviceTests/Logs/Test/Test-ReviewTrace-2026.07.21_02-53-15-+0900.xcresult`
- This physical-device result predates commits `5c0394c` and `91a378c`; the current 28-test English-locale and String Catalog revision needs a fresh device run.

### Latest-revision physical-device attempt

- The paired iPhone 15 Pro was available and Xcode compiled the latest revision for `iphoneos`.
- Final signing stopped at `ReviewTrace.debug.dylib` with `errSecInternalComponent`.
- `security find-identity -v -p codesigning` still reported the Apple Development identity as valid, so this is classified as a local keychain/private-key access blocker rather than a source compile failure.
- Because signing did not finish, the latest revision was not installed or launched on the phone in this attempt.

Temporary result-bundle paths are local evidence from this run and are not committed artifacts.

## Not yet proven

- The connected phone was locked when a screenshot was requested, so no unlocked ReviewTrace UI screenshot was accepted as proof.
- A privacy-safe 60–90 second real-iPhone recording with microphone narration has not been created.
- Real-media import, Apple Speech completion, five or more correctly oriented timeline frames, and timestamp seek have not been manually verified end to end on the phone.
- A real English recording has not yet been processed with the new `en-US` selector on the phone.
- The ReviewTrace-to-Codex-to-ReviewTrace before/after loop has not been completed.
- Sample processing time has not been measured.
- Archive, TestFlight, public YouTube playback, `/feedback` session ID, and final Devpost submission have not been verified.

## Interpretation

The earlier physical-device results prove that the pre-`5c0394c` revision signed, installed, launched, and ran its then-current unit tests on the connected iPhone. The latest source compiles and passes all Simulator tests, but the latest physical-device signing attempt did not finish. Neither result proves the pending real-media workflow or release readiness. Follow `Samples/README.md` after the device owner unlocks the phone and records the final sample.
