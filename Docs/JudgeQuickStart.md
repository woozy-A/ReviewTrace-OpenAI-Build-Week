# ReviewTrace Judge Quick Start

ReviewTrace is an iPhone developer tool. It does not require an account, API key, server, or third-party package.

## Fastest evaluation routes

### 1. Watch the complete product flow

- Public YouTube demo: https://youtu.be/X_OToLfUBK4
- Maximum length: under three minutes
- The final video must show a real working flow and explain how Codex and GPT-5.6 were used.

This is the only route that should be treated as final real-media evidence after the owner completes the recording checklist.

### 2. Run the prebuilt Simulator app without compiling

Download these assets from the [Build Week release](https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week/releases/tag/build-week-demo):

- `ReviewTrace-Simulator.app.zip`
- `ReviewTrace-Simulator.app.zip.sha256`

Requirements:

- Mac with Xcode 26.6 and an iOS Simulator runtime
- The packaged app contains both arm64 and x86_64 Simulator slices.

Install:

```sh
unzip ReviewTrace-Simulator.app.zip
xcrun simctl list devices available
xcrun simctl boot <AVAILABLE_UDID>
xcrun simctl install <AVAILABLE_UDID> ReviewTrace.app
xcrun simctl launch <AVAILABLE_UDID> woozyLAB.ReviewTrace
```

The prebuilt app is intended for navigation, English/Korean localization, persisted sessions, export layout, and judge-path inspection. Simulator behavior is not presented as proof of real-iPhone Apple Speech performance.

The published artifact was rebuilt from final app commit `76c1581`, checksum-verified, installed, and launched on an iPhone 17 Pro Simulator before publication.

The release artifact is reproducible with:

```sh
Scripts/package-simulator-app.sh
```

### 3. Build and test the source

1. Open `OpenAi_ReviewTrace.xcodeproj`.
2. Select the shared `ReviewTrace` scheme.
3. Choose an iOS 17+ iPhone Simulator.
4. Press Command-R.
5. Run Product → Test, or use the `xcodebuild test` command in the root README.

Verified source checks at the Build Week handoff:

- unsigned generic iOS Debug build: passed;
- iPhone 17 Pro Simulator on iOS 26.3.1: 30 tests passed, 0 failed;
- English and Korean display languages: switched through the actual Settings UI;
- signed Archive, Apple Distribution IPA export, and internal TestFlight processing for `1.0 (1)`: complete;
- installation and real-media smoke testing of the final TestFlight build on a physical iPhone: not yet claimed.

## Test the primary workflow

Until `Samples/reviewtrace-narrated-self-review.mov` is committed, use a privacy-safe 60–90 second portrait iPhone screen recording with microphone audio.

1. In Settings, choose **App Language → English**.
2. On Home, choose the language actually spoken in the recording. Use **English (en-US)** for the submission demo.
3. Import the screen recording and allow Photo Library and Speech Recognition access.
4. Wait for the review to reach **Ready**.
5. Open **Timeline → Readable**. Confirm that rows show matching frames and that tapping a row seeks the video.
6. Open **Timeline → Original**. Confirm that the original transcript remains available without frame slots.
7. Open **Codex** and inspect **Direct Review Handoff**.
8. Open **Export** and inspect the recording or optimized parts, `full-transcript.md`, and `codex-prompt.md` included in the explicit share flow.

## Product boundary

ReviewTrace does not call an OpenAI runtime API and does not modify a repository by itself. It preserves the recording, timestamped speech, and implementation instructions so the developer can explicitly hand that evidence to Codex. The human remains responsible for product decisions and final verification.

See [Verification_2026-07-21.md](Verification_2026-07-21.md) for the exact evidence boundary and [HackathonDemoRecordingGuide.md](HackathonDemoRecordingGuide.md) for the final self-review route.
