# ReviewTrace Devpost Submission Working Copy

> 이 문서는 제출 준비용 원본입니다. 영어 문구를 이해하기 쉽게 한국어 확인 항목과 함께 저장합니다. Devpost 안내에 따라 프로젝트 설명은 그대로 복사해 제출하지 말고, 아래 `OWNER EDIT` 문장만큼은 본인의 말투로 한 번 고친 뒤 소리 내어 읽어보세요.

## Live submission status

- Hackathon: OpenAI Build Week
- Devpost project ID: `1355065`
- Current project name: `Untitled`
- Current state: `submission_pre_draft`
- Project URL: <https://devpost.com/software/1355065>
- Submission deadline: **2026-07-22 09:00 KST** (`2026-07-21 17:00 PT`)
- Recommended category: **Developer Tools**

Do not create a second Devpost project. Update project `1355065` after every owner-only field below is complete.

## Core project fields

### Title

```text
ReviewTrace
```

### Tagline

```text
Review on iPhone. Fix with Codex.
```

### One-sentence summary

```text
ReviewTrace turns a narrated iPhone app review into a timestamp-aligned handoff that Codex can use to modify the real repository.
```

### Category

```text
Developer Tools
```

### Built with

```text
Swift, SwiftUI, AVFoundation, AVKit, PhotosUI, Apple Speech, XCTest, Xcode, Codex, GPT-5.6
```

## English project description draft

### Inspiration

Codex can already understand natural product feedback and modify a repository. The remaining friction appears after I test an app on a real iPhone. I notice a problem while using the app, explain it out loud, and record the screen, but later I still have to rewatch the recording and type the same feedback again.

**OWNER EDIT:** Rewrite the next sentence in your own words before submission.

> I built ReviewTrace to preserve what I said and what I was seeing at the same moment, so Codex can act on the original review context.

### What it does

ReviewTrace imports an iPhone screen recording with microphone audio and transcribes the spoken review with Apple Speech. It keeps each transcript segment aligned to the original video timeline.

The developer can:

- choose Korean or English as the spoken language for each review;
- use the interface in English or Korean independently from the spoken language;
- inspect readable and original transcript timelines;
- see a matching video frame beside each readable screen-recording row;
- tap a row to seek to the corresponding moment in the recording;
- export Markdown, JSON, SRT, and VTT files; and
- explicitly share the recording, timestamped transcript, and direct implementation instructions with Codex.

ReviewTrace does not generate an automatic issue summary or make product decisions for the developer. The recording shows what happened, the transcript preserves what the reviewer said, the repository explains how the app is built, and the human remains the final decision-maker.

Large videos can be prepared separately from transcription using a cancellable optimization flow. The policy targets 540p, 30 fps, 2.7 Mbps video, and 128 kbps audio; output is split by timestamp when necessary so each part remains at or below 280 MB. Every split part includes both its original-recording range and its file-local time range for Codex.

### How I built it

ReviewTrace is an iPhone SwiftUI app with no third-party package dependencies and no OpenAI runtime API call.

AVFoundation extracts audio from the selected recording. The audio is divided into silence-aware chunks with overlap, Apple Speech transcribes each chunk, and ReviewTrace maps chunk-local timestamps back to the original video time. Completed chunk results can be reused during retry.

For visual context, AVFoundation extracts a transformed frame at each readable timeline row's start time. Frames load asynchronously and use a bounded memory cache. Cancellation or a failed frame never blocks the transcript or timestamp seeking.

The handoff generator creates direct instructions for Codex. It tells Codex to inspect the repository, use the recording and transcript as evidence, implement only explicit requests, respect later corrections, make focused changes, and run relevant verification.

Apple String Catalogs provide English and Korean app copy plus localized permission descriptions. The app display language is independent from the spoken language selected for transcription.

GPT-5.6 helped me narrow the product scope and define the Build Week plan. Codex inspected the existing code, preserved the working pipeline, implemented the focused additions, added tests, and ran build, test, and Simulator checks.

### Pre-existing work and Build Week work

ReviewTrace began as a private exploratory prototype. Before Build Week, it already contained media import, local session persistence, Apple Speech transcription, chunk processing, retry, transcript timelines, export formats, and large-video optimization.

During Build Week, I extended that baseline with:

- a direct, implementation-first Codex handoff;
- timestamp-matched visual previews in the readable timeline;
- frame caching, orientation handling, and cancellation behavior;
- independent Korean and English speech selection for each review;
- English and Korean String Catalog localization;
- Codex-first sharing and product copy;
- focused prompt, frame, locale, cache, compression-policy, and regression tests; and
- a documented judge path and safe demo-workspace workflow.

The baseline and new work are separated in the Git commit history and `CHANGELOG.md`.

### Challenges I ran into

The hardest technical challenge was preserving accurate time across multiple audio chunks. Each transcript begins with chunk-local timestamps, while the final result must point to the exact moment in the original recording. Overlap protects words spoken near a chunk boundary, but it also requires duplicate reduction during timeline merging.

Video frames introduced a different set of problems: portrait orientation, asynchronous scrolling, repeated extraction, cancellation, and corrupt or missing media. The preview had to remain useful without becoming a dependency for transcript completion.

The product challenge was equally important. I chose not to add another AI-generated issue layer. ReviewTrace needed to preserve human intent and supply Codex with evidence, not replace the reviewer's judgment.

### Accomplishments that I am proud of

I am proud that ReviewTrace connects spoken human feedback to the exact screen moment without hiding the original evidence. The Build Week version gives Codex a direct implementation contract instead of forcing every spoken sentence into an issue, severity, or priority.

I am also proud that English transcription and English UI are separate, explicit choices. This lets a Korean-speaking developer use a familiar interface while recording an English review and English hackathon demo.

### What I learned

I learned that multimodal developer tools do not always need more model-generated interpretation. Sometimes the most useful layer is reliable synchronization: what was visible, what was said, and where the code lives.

I also learned to separate implementation proof from device proof. A successful compile or unit test does not prove real-media transcription, device performance, signing, or a complete before-and-after workflow. Those claims need their own evidence.

### What's next

The immediate next step is to finish the privacy-safe real-iPhone demonstration: process an English narrated ReviewTrace recording, verify its timestamps and previews, pass the package to Codex, and show a visible before-and-after repair.

After that, I want to measure processing performance on more devices, validate TestFlight distribution, and consider additional speech locales only after the core workflow is proven reliable.

Add this sentence only after the real iPhone → ReviewTrace → Codex → repaired app loop has actually succeeded and appears in the final video:

> For the final Build Week proof, I used ReviewTrace to review ReviewTrace itself, handed two timestamped English requests to Codex, and verified the repaired interface with a new build.

## Devpost custom fields

| Field ID | Devpost field | Prepared answer / status |
| --- | --- | --- |
| `27945` | Submitter Type | `OWNER CONFIRM`: likely `Individual` |
| `27946` | Country of Residence | `OWNER CONFIRM`: likely `Korea Republic of` |
| `27947` | Category | `Developer Tools` |
| `27948` | Code repository URL | <https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week> |
| `27949` | Project/test link and instructions | Use the prepared text below after adding the video/release URLs |
| `27950` | `/feedback` Session ID | `OWNER_TODO_FEEDBACK_SESSION_ID` |
| `27951` | Developer-tool installation/testing | Use the prepared text below |

### Field `27949`: project/test link and instructions

```text
No credentials are required. Start with Docs/JudgeQuickStart.md in the repository.

Public demo: OWNER_TODO_YOUTUBE_URL
Prebuilt universal Simulator app: https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week/releases/tag/build-week-demo

For the source path, open OpenAi_ReviewTrace.xcodeproj, select the shared ReviewTrace scheme, and run on an iOS 17+ iPhone Simulator. For the primary media path, use a privacy-safe 60–90 second portrait iPhone screen recording with microphone audio and select the actual spoken locale before import.
```

### Field `27951`: developer-tool installation and testing

```text
Platform: iPhone, iOS 17 or later. Verified toolchain: Xcode 26.6 (17F113). No login, server, API key, or package installation is required.

No-rebuild route: download ReviewTrace-Simulator.app.zip from the Build Week GitHub release, unzip it, boot an iOS 26.5 Simulator, then run:
xcrun simctl install <UDID> ReviewTrace.app
xcrun simctl launch <UDID> woozyLAB.ReviewTrace

Source route: open OpenAi_ReviewTrace.xcodeproj, select the shared ReviewTrace scheme, choose an iOS 17+ iPhone Simulator, and press Command-R. The root README contains unsigned generic-build and XCTest commands. The current suite contains 28 tests.

Primary workflow: Settings > App Language > English; Home > Language Spoken in This Review > English (en-US); import a narrated portrait screen recording; inspect Timeline > Readable; tap a timestamp to seek; inspect Codex > Direct Review Handoff; inspect Export > Share Review with Codex.

The Simulator route verifies the UI and judge path but is not claimed as real-device Apple Speech performance evidence. See Docs/Verification_2026-07-21.md for the exact boundary.
```

## Under-three-minute demo plan

Target length: **2:40–2:50**. Keep every actual product claim visible on screen. Cut loading and typing. A public **unlisted** YouTube link is acceptable, but verify it while signed out.

| Time | Screen | Short English narration |
| --- | --- | --- |
| `0:00–0:15` | Real iPhone testing and raw screen recording | “Codex can already change an app from natural language. But after I test the real app on my iPhone, I still have to explain the same feedback again.” |
| `0:15–0:28` | ReviewTrace Home | “I built ReviewTrace to preserve what I said and what I was seeing at the same moment.” |
| `0:28–0:43` | Build Week changelog or commit view | “ReviewTrace began as a private prototype. During Build Week, I used GPT-5.6 to focus the product, and Codex to build and test the new developer workflow.” |
| `0:43–1:02` | English UI, English spoken-language selector, import | “I select English for this review and import an iPhone screen recording with microphone audio.” |
| `1:02–1:22` | Processing, then readable timeline | “ReviewTrace transcribes the recording and keeps every sentence aligned to the original video time.” |
| `1:22–1:39` | Frame previews and tap-to-seek | “Each readable row shows the matching screen moment. When I tap a row, the video moves to that timestamp.” |
| `1:39–1:56` | Codex and Export tabs | “ReviewTrace does not replace my feedback with an AI summary. It shares the recording, timestamped transcript, and direct instructions with Codex.” |
| `1:56–2:17` | Intentionally regressed demo worktree | “For the final test, I use ReviewTrace to review ReviewTrace itself.” Then speak the two repair lines from `HackathonDemoRecordingGuide.md`. |
| `2:17–2:34` | Imported English transcript, Codex diff, build/test result | “Codex matches my spoken requests to the repository, changes only the relevant SwiftUI code, and runs the build and tests.” |
| `2:34–2:48` | Before/after and final logo | “Human judgment stays in the loop, and ReviewTrace makes it actionable for Codex. Review on iPhone. Fix with Codex.” |

The Korean meaning and pronunciation guide for every spoken repair request is in [HackathonDemoRecordingGuide.md](HackathonDemoRecordingGuide.md).

## Repository publication decision

- Public repository: <https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week>
- License: MIT
- Git history: all author and committer emails were rewritten to the authenticated GitHub `noreply` address before the first public push.
- The pre-existing private `woozy-A/ReviewTrace` repository was not overwritten.

## Final owner checklist

- [ ] Confirm Submitter Type and Country of Residence.
- [ ] Personalize the `OWNER EDIT` sentence and read the English description aloud.
- [x] Choose a public repository and add the MIT license.
- [x] Rewrite the existing commit email to GitHub `noreply` before the first public push.
- [x] Authenticate GitHub CLI.
- [x] Create and push the public repository.
- [x] Upload `ReviewTrace-Simulator.app.zip` and its checksum as release assets.
- [ ] Record the privacy-safe real-iPhone sample and fill every `TBD` in `Samples/README.md`.
- [ ] Complete the ReviewTrace → Codex → repaired ReviewTrace proof before claiming it.
- [ ] Upload the final video to YouTube, keep it under three minutes, and verify it while signed out.
- [ ] Run `/feedback` in the primary Codex task and copy the session ID.
- [ ] Replace every `OWNER_TODO_*` token in this document and the judge guide.
- [ ] Add a thumbnail and screenshots on Devpost.
- [ ] Update Devpost project `1355065`, save it, and verify the project page.
- [ ] Submit—not only save as draft—and verify the green `Submitted` state before **2026-07-22 09:00 KST**.
