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
- Result: 25 passed, 0 failed, 0 skipped
- Latest result bundle during this implementation run: `/tmp/ReviewTrace-English-FullTests/Logs/Test/Test-ReviewTrace-2026.07.21_03-27-35-+0900.xcresult`

### Language-selection UI smoke check

- Korean app UI: the separate `한국어 (ko-KR) / English (en-US)` spoken-language selector rendered without clipping.
- English app UI: `English (en-US)` could be selected independently and the English helper copy rendered without clipping.
- These checks prove layout and persistence wiring on Simulator, not a real Apple Speech transcription result.

### Physical iPhone build, install, launch, and XCTest

- Device class: iPhone 15 Pro
- OS: iOS 26.5.2
- Developer Mode: enabled
- Signed Debug build: passed
- Install: passed; no prior app with `woozyLAB.ReviewTrace` was present
- Launch request: passed; the ReviewTrace process remained listed after launch
- XCTest: 22 passed, 0 failed
- Result bundle: `/tmp/OpenAiReviewTrace-DeviceTests/Logs/Test/Test-ReviewTrace-2026.07.21_02-53-15-+0900.xcresult`
- This physical-device result predates commit `51ad510`; the current 25-test English-locale revision needs a fresh device run.

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

The physical-device results prove that the current source signs, installs, launches, and runs its unit tests on the connected iPhone. They do not prove the pending real-media workflow or release readiness. Follow `Samples/README.md` after the device owner unlocks the phone and records the final sample.
