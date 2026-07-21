# ReviewTrace

> Review on iPhone. Fix with Codex.

ReviewTrace is an iPhone developer tool that imports a narrated screen recording, aligns the reviewer’s speech to the original media timeline, and prepares the recording, timestamp-aligned transcript, and direct implementation instructions for Codex.

The app preserves the human review record; it does not replace the human reviewer. The reviewer decides what belongs in the product, and sharing to Codex is always initiated by the user.

## Current verification status

- The app and test targets build from `OpenAi_ReviewTrace.xcodeproj` with Xcode 26.6 (17F113).
- The final submission XCTest run passes on an iPhone 17 Pro Simulator running iOS 26.3.1: 30 tests, 0 failures.
- An unsigned generic iOS build succeeds with `CODE_SIGNING_ALLOWED=NO`.
- A signed `1.0 (1)` archive was created, an App Store IPA was exported with Apple Distribution signing, and TestFlight build `1.0 (1)` finished processing and is **Ready to Test** in the connected internal testing group.
- Before the selectable speech-locale and String Catalog additions, a signed Debug build installed and launched on an iPhone 15 Pro running iOS 26.5.2, and all 22 then-current XCTest cases passed on that physical phone. The latest 30-test revision still needs a new physical-device run.
- The final TestFlight build has not yet been installed or smoke-tested on a physical iPhone. Real-media import, English transcription, timestamp seeking, export, processing-time measurement, and the final real-iPhone self-review loop still require device evidence.

See [Docs/Verification_2026-07-21.md](Docs/Verification_2026-07-21.md) for the exact proof boundary.
Judges can start with [Docs/JudgeQuickStart.md](Docs/JudgeQuickStart.md).

## What it does

1. The developer records an iPhone app review with iOS Screen Recording and microphone audio enabled.
2. The developer chooses the language actually spoken in that review (`ko-KR` or `en-US`) independently from the app display language, then ReviewTrace imports the selected video into app-local storage.
3. AVFoundation extracts audio and divides it into silence-aware 45-second chunks with overlap.
4. Apple Speech creates timestamped transcript segments.
5. ReviewTrace presents readable and original timelines; a readable video row shows its matching frame and still seeks the player when tapped.
6. ReviewTrace prepares a direct Codex handoff containing the media, `full-transcript.md`, and `codex-prompt.md`.
7. The developer explicitly shares the package to the Codex task for the target repository.

Existing audio-file import, retry, persistence, subtitle export, and large-video optimization remain available as secondary utilities.

## Why Developer Tools

Codex can already understand natural product feedback and modify a repository. ReviewTrace supplies the missing input layer: the exact screen moment and the human instruction that occurred there. Video remains the source of truth for screen state and interaction flow, the transcript remains the source of truth for what was said, and the repository remains the source of truth for implementation context.

ReviewTrace does not create an AI-generated issue dashboard or silently turn every spoken sentence into a task. Its handoff tells Codex to implement explicit requests, ignore praise and narration, prefer small safe changes, run relevant verification, and report which timestamps led to which files.

## Build Week features

ReviewTrace began as a private exploratory prototype. During OpenAI Build Week, the existing prototype was imported as an explicit baseline and extended into a coherent Codex developer workflow:

- direct review instructions replaced analysis-first issue-summary prompts;
- screen-recording and audio-only evidence rules were made explicit;
- Codex package sharing became the primary export action;
- readable screen-recording rows gained asynchronous, cached visual previews;
- Korean and English speech recognition became a per-review choice, independent from the app display language and safe across retries and cached chunks;
- all app and permission copy moved to Apple String Catalogs, with an in-app English/Korean display-language switch;
- prompt, cache, cancellation, and regression tests were added;
- the supported build and judge paths were documented.

The final real-iPhone self-review and before/after evidence remain pending; see [Samples/README.md](Samples/README.md).

## Architecture

```text
iOS Screen Recording with microphone ON
  -> user-selected spoken locale (ko-KR or en-US)
  -> user-selected Photos import
  -> app Documents/Sessions storage
  -> AVFoundation audio extraction
  -> 45 s silence-aware chunks with 1.5 s overlap
  -> Apple Speech transcription
  -> readable and original timestamp timelines
  -> on-demand, memory-cached video frames for readable rows
  -> recording + full-transcript.md + codex-prompt.md
  -> user-initiated Codex handoff
  -> repository changes, build/tests, and human verification
```

All core processing is implemented with SwiftUI, AVFoundation, PhotosUI, and Speech. There is no package dependency, server, login, or OpenAI runtime API in the app.

## How GPT-5.6 and Codex were used

GPT-5.6 was used to separate the pre-existing prototype from the Build Week scope and challenge the product boundary: video should remain the source of truth, human judgment should remain explicit, and the app should prepare evidence for Codex instead of generating another automatic issue summary.

Codex audited the existing pipeline, preserved its working import/transcription/export path, implemented the direct handoff, timestamped frame previews, English transcription and localization, added regression tests, and completed build, Archive, export, and TestFlight preparation. `CHANGELOG.md` and the focused commit history record those decisions and implementation steps.

ReviewTrace itself makes no OpenAI runtime API calls. The app prepares evidence for Codex and exposes normal copy/share controls; the user chooses when and where to send it.

## Supported platform

- iPhone only
- iOS 17.0 or later
- Swift 5 language mode
- Verified toolchain: Xcode 26.6 (17F113)
- No Swift Package Manager dependencies

Other Xcode versions may work, but are not claimed as verified.

## Setup and run

1. Clone or download the repository on macOS.
2. Open `OpenAi_ReviewTrace.xcodeproj` in Xcode.
3. Select the shared `ReviewTrace` scheme.
4. Choose an iOS 17+ iPhone Simulator or a connected iPhone.
5. For a physical device, select your development team and use a bundle identifier available to that team.
6. Build and run with Command-R.
7. For an English judge or demo path, choose **Settings → App Language → English**. This is independent from the spoken language selected on Home.

The app requests:

- Photo Library read access to import a selected recording;
- Photo Library add access only when the user chooses to save an export;
- Speech Recognition access to transcribe spoken review audio.

The app does not record the microphone and therefore has no microphone permission. Create the source recording with iOS Screen Recording and turn the microphone on in Control Center before recording.

### Command-line verification

List locally available destinations:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -showdestinations \
  -project OpenAi_ReviewTrace.xcodeproj \
  -scheme ReviewTrace
```

Compile for a generic iOS device without signing:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project OpenAi_ReviewTrace.xcodeproj \
  -scheme ReviewTrace \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/OpenAi_ReviewTrace-Build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run the test suite after replacing `<AVAILABLE_UDID>` with a destination reported by the first command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project OpenAi_ReviewTrace.xcodeproj \
  -scheme ReviewTrace \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<AVAILABLE_UDID>' \
  -derivedDataPath /private/tmp/OpenAi_ReviewTrace-Tests \
  CODE_SIGNING_ALLOWED=NO
```

An unsigned generic build proves compilation only. It is not Simulator, real-device, Archive, or TestFlight proof.

## Judge test path

For the fastest source and prebuilt-Simulator routes, start with [Docs/JudgeQuickStart.md](Docs/JudgeQuickStart.md). The final demo video is the real-device media evidence; the complete repeatable media path below uses the privacy-safe file described in [Samples/README.md](Samples/README.md).

Until that real sample is recorded and committed, judges can use their own 60–90 second vertical iPhone screen recording with microphone narration.

1. Add the sample recording to Photos. For Simulator testing:

   ```sh
   xcrun simctl addmedia <AVAILABLE_UDID> Samples/reviewtrace-narrated-self-review.mov
   ```

2. Launch ReviewTrace and set **Language Spoken in This Review** to the language actually used in the recording. Use **English (en-US)** for the final hackathon recording.
3. Choose **Import Screen Recording**, select the recording, and allow Photo Library and Speech Recognition access.
4. Keep the app in the foreground until the review reaches **Ready**.
5. In **Timeline → Readable**, confirm at least five correctly oriented previews and tap a row to seek to the matching video moment.
6. Switch to **Original** and confirm the original transcript layout has no frame slots.
7. In **Codex**, inspect **Direct Review Handoff** and use **Copy Review Instructions**.
8. In **Export**, confirm **Share Review with Codex** is the primary action and that the package includes the recording or optimized parts, `full-transcript.md`, and `codex-prompt.md`.
9. Run the XCTest command above.

For the exact ReviewTrace-on-ReviewTrace screen route, Korean explanation, short English lines, and Korean pronunciation, follow [Docs/HackathonDemoRecordingGuide.md](Docs/HackathonDemoRecordingGuide.md).

The expected processing time is intentionally not estimated. It must be measured with the committed sample on the target iPhone and recorded in `Samples/README.md` before submission.

## Sample input

The required public sample is specified in [Samples/README.md](Samples/README.md). The file itself is currently pending a privacy-safe real-iPhone recording. This repository does not substitute a synthetic video and call it device proof.

## Privacy

- ReviewTrace processes only files the user explicitly selects.
- Imported sessions and generated documents are stored locally in the app container.
- Nothing is uploaded to an OpenAI API by the runtime app.
- Sharing uses an explicit system share or copy action and previews what is included.
- Sessions can be deleted from the review detail screen.
- Public demo media should use Do Not Disturb and contain no notifications, account data, private messages, copyrighted music, or third-party content without permission.

Apple Speech is configured with `requiresOnDeviceRecognition = false`. Depending on device, locale, and system availability, transcription may use Apple services. Do not treat the current build as guaranteed offline or fully on-device speech recognition.

## Known limitations

- Speech transcription currently supports `ko-KR` and `en-US`. The language is fixed for each imported review; changing it afterward does not retroactively re-transcribe a completed session.
- App and permission copy is maintained in `Localizable.xcstrings` and `InfoPlist.xcstrings`; Apple-provided runtime error text may still follow the device language.
- ReviewTrace imports recordings; it does not include a ReplayKit recording extension.
- Timeline thumbnails are memory-only previews for readable screen-recording rows and are not persistent exports.
- Recordings that exceed the Codex compression threshold require the user to prepare optimized 540p parts before sharing the complete media package.
- The app does not modify a repository itself, summarize issues with an OpenAI API, or make product decisions for the reviewer.
- Signed Archive creation, Apple Distribution IPA export, and TestFlight processing for `1.0 (1)` are complete. Installation and end-to-end smoke testing of that TestFlight build on a real iPhone remain pending.

## Build Week changelog

See [CHANGELOG.md](CHANGELOG.md) for the dated baseline and feature commits. Git history intentionally separates the imported pre-Build Week prototype from Build Week changes.

## Submission checklist still requiring owner action

- Record and commit the real narrated sample, then measure its processing time.
- Install TestFlight `1.0 (1)` on a real iPhone and complete the short smoke-test checklist.
- Complete the ReviewTrace-on-ReviewTrace real-iPhone loop and capture before/after evidence.
- Publish a public YouTube demo under three minutes and verify it while logged out.
- Paste the prepared repository, release, and source-build test paths into the Devpost project.
- Run `/feedback` in the primary Codex task and enter the actual session ID.
- Choose the Developer Tools category and move the Devpost project from pre-draft to submitted.

The prepared English field copy, short demo script, custom-field map, and final owner checklist are in [Docs/DevpostSubmission.md](Docs/DevpostSubmission.md).

## License

ReviewTrace is available under the [MIT License](LICENSE).
