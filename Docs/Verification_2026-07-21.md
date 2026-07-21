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
- OS: iOS 26.3.1
- Result: 30 passed, 0 failed, 0 skipped
- Clean-checkout final rerun: 2026-07-21 16:25 KST, detached at commit `76c1581`
- Result bundle: `/private/tmp/ReviewTrace-FinalClean-20260721-1625.xcresult`

### English/Korean String Catalog UI smoke check

- The app was installed and launched on the dedicated iPhone 17 Pro Simulator.
- Settings changed the app display language from English to Korean and back to English through the actual language picker.
- Home and Settings headings, privacy text, buttons, tab labels, and the per-review spoken-language helper changed immediately from `Localizable.xcstrings`.
- The spoken-review selector remained an independent `한국어 (ko-KR) / English (en-US)` choice.
- At the committed catalog revision used for this smoke check, `Localizable.xcstrings` contained 194 source keys with 194 Korean localizations; static source lookup found 177 referenced keys and 0 missing keys.
- `InfoPlist.xcstrings` compiled English and Korean purpose strings for Photo Library read/add and Speech Recognition permissions.
- These checks prove String Catalog compilation, layout, and persistence wiring on Simulator, not a real Apple Speech transcription result.

### Prebuilt Simulator judge artifact

- `Scripts/package-simulator-app.sh` completed a Release build for `generic/platform=iOS Simulator` with signing disabled.
- The release was rebuilt from a clean worktree detached at final app commit `76c1581`.
- The packaged executable contains both `arm64` and `x86_64` Simulator slices.
- Public release asset: [ReviewTrace-Simulator.app.zip](https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week/releases/download/build-week-demo/ReviewTrace-Simulator.app.zip) (2.5 MB; local packaging output remains ignored by Git).
- SHA-256: `16ca268925bcff6697264dcbe195926e068a8b1d1b82387953cb584c610956bf`
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
- This physical-device result predates commits `5c0394c` and `91a378c`; the current 30-test English-locale and String Catalog revision needs a fresh device run.

### Earlier latest-revision physical-device attempt

- The paired iPhone 15 Pro was available and Xcode compiled the latest revision for `iphoneos`.
- Final signing stopped at `ReviewTrace.debug.dylib` with `errSecInternalComponent`.
- `security find-identity -v -p codesigning` still reported the Apple Development identity as valid, so this is classified as a local keychain/private-key access blocker rather than a source compile failure.
- Because signing did not finish, the latest revision was not installed or launched on the phone in this attempt.

### Archive, distribution export, and TestFlight

- Version/build: `1.0 (1)`
- Bundle identifier: `woozyLAB.ReviewTrace`
- A signed archive was created successfully.
- The App Store IPA was exported with Apple Distribution signing and an App Store provisioning profile.
- The exported IPA has `beta-reports-active=true`, `get-task-allow=false`, the Privacy Manifest, and `ITSAppUsesNonExemptEncryption=false`.
- IPA SHA-256: `36803abd03abbf66a1a564cf5b40cfbdcbdf2bd49f2cd4d1a668b8d6c23d5874`
- App Store Connect upload and processing completed; TestFlight build `1.0 (1)` is **Ready to Test** in the connected internal testing group.
- An internal testing group and the owner account were connected to the build.
- Physical-iPhone installation and smoke testing of this TestFlight build have not yet been performed.

Temporary result-bundle paths are local evidence from this run and are not committed artifacts.

## Not yet proven

- The connected phone was locked when a screenshot was requested, so no unlocked ReviewTrace UI screenshot was accepted as proof.
- A privacy-safe 60–90 second real-iPhone recording with microphone narration has not been created.
- Real-media import, Apple Speech completion, five or more correctly oriented timeline frames, and timestamp seek have not been manually verified end to end on the phone.
- A real English recording has not yet been processed with the new `en-US` selector on the phone.
- The ReviewTrace-to-Codex-to-ReviewTrace before/after loop has not been completed.
- Sample processing time has not been measured.
- Installation and end-to-end smoke testing of TestFlight `1.0 (1)` on a physical iPhone have not been verified.
- Public YouTube playback, `/feedback` session ID, and final Devpost submission have not been verified.

## Interpretation

The earlier physical-device results prove that the pre-`5c0394c` revision signed, installed, launched, and ran its then-current unit tests on the connected iPhone. The latest source passes all 30 Simulator tests, and the distribution pipeline now proves Archive creation, Apple Distribution export, upload, and TestFlight processing. Those release checks still do not prove installation or the pending real-media workflow on a physical iPhone. Follow `Samples/README.md` when recording the final sample and keep the TestFlight smoke test as a separate evidence step.
