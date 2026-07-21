# ReviewTrace Devpost Submission Working Copy

> 이 문서는 제출 준비용 원본입니다. 영어 문구를 이해하기 쉽게 한국어 확인 항목과 함께 저장합니다. Devpost 안내에 따라 저장된 프로젝트 설명을 소리 내어 한 번 읽고, 본인의 말투와 다른 문장이 있다면 제출 전에 직접 고쳐 주세요.

## Live submission status

- Hackathon: OpenAI Build Week
- Devpost project ID: `1355065`
- Current project name: `ReviewTrace`
- Current project state: `published` (project page saved; hackathon submission is not final)
- Project URL: <https://devpost.com/software/reviewtrace>
- Submission deadline: **2026-07-22 09:00 KST** (`2026-07-21 17:00 PT`)
- Recommended category: **Developer Tools**

Do not create a second Devpost project. Continue using project `1355065` for the final hackathon submission.

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
I speak while testing my app on an iPhone. ReviewTrace keeps my words connected to the exact screen moment so Codex can make the changes later.
```

### Category

```text
Developer Tools
```

### Built with

```text
Swift, SwiftUI, AVFoundation, AVKit, PhotosUI, Apple Speech, XCTest, Xcode, Codex, GPT-5.6
```

## Owner-edited English project description

### Inspiration

I do not know how to code in the traditional sense.

But with Codex, I have been able to publish an app and start building several more in only two months. It changed the way I think about everyday problems. Instead of simply accepting an inconvenience, I now think, “Maybe I can build something for that.”

ReviewTrace came from one of those small frustrations.

After testing an app on a real iPhone, I would record the screen and explain problems out loud. But later, I still had to watch the recording again and type the same feedback into Codex.

I wanted a simple tool that could preserve what I said and when I said it, so I would not have to rewrite the same review twice.

### What it does

ReviewTrace imports an iPhone screen recording with microphone audio and turns the spoken review into a timestamped timeline.

Each comment stays connected to the moment it was spoken. I can tap a comment to return to that point in the video, see the matching screen frame, and export a Codex-ready package containing the recording, transcript, and implementation requests.

ReviewTrace does not replace my judgment with an automatic issue summary. It simply preserves the review I already made so Codex can work from the original context.

The app supports Korean and English speech transcription, and its interface can also be used in Korean or English independently from the spoken language.

Large recordings can be optimized separately from transcription with progress, cancellation, and retry. The export policy targets 540p, 30 fps, 2.7 Mbps video, and 128 kbps audio. When a recording must be split to stay at or below 280 MB per file, every part includes both its original-recording time range and its file-local time range for Codex.

### How I built it

ReviewTrace is a native SwiftUI iPhone app built with Apple Speech, AVFoundation, AVKit, PhotosUI, and XCTest.

It extracts audio from a screen recording, divides longer audio into silence-aware overlapping chunks, transcribes each chunk, and maps every timestamp back to the original video timeline.

For visual context, it extracts the video frame that matches each readable transcript row. Frames load asynchronously and are cached to avoid blocking the timeline while scrolling.

The export flow creates a Codex-ready review package with the recording, timestamped transcript, and clear implementation instructions.

ReviewTrace itself makes no OpenAI runtime API calls. GPT-5.6 and Codex were used to shape and build the developer workflow, while runtime media processing stays in the Apple-platform app.

ReviewTrace began as a private experimental prototype. Before Build Week, it already included media import, Apple Speech transcription, chunk processing, retry, transcript timelines, export formats, and large-video optimization.

During Build Week, GPT-5.6 helped me clarify the product idea and reduce it to one focused workflow. Codex inspected my experimental code, preserved the working pipeline, and added the direct Codex handoff, timestamped visual timeline, Korean and English localization, regression tests, build verification, and release preparation.

The Build Week version came together in one focused day because Codex allowed me to turn that experiment into a coherent, testable developer tool.

### Challenges I ran into

The main technical challenge was keeping speech, video, and timestamps synchronized, especially when longer recordings were divided into multiple audio chunks.

Each chunk produces its own local timestamps, but the final transcript must still point to the exact moment in the original recording. Overlapping chunks also help preserve words near a boundary, but they require duplicate reduction when the timeline is merged.

The more important product challenge was deciding what not to add.

Codex already understands natural product feedback well, so ReviewTrace did not need another AI layer to rewrite my words into issues, priorities, or summaries. It only needed to preserve the original evidence reliably.

### Accomplishments that I am proud of

I am proud that the Build Week version turned a private experiment into a focused developer workflow without hiding the original evidence.

ReviewTrace now keeps the recording, timestamped speech, screen frames, and implementation instructions together while leaving the final judgment with me.

I am also proud that a small personal experiment became a working iPhone developer tool during one focused day of Build Week work with Codex.

### What I learned

I learned that Codex does more than help me write code. It expands the range of problems I believe I can solve.

Before Codex, building an app was something I could only imagine. Now, when I encounter an inconvenience, I can consider making a small tool for myself.

ReviewTrace may not be needed forever. I expect Codex will eventually understand a review video directly and apply the requested changes without an intermediate app. That is fine. ReviewTrace is a simple bridge for the tools we have today.

What matters more is the change in mindset. Codex is allowing a non-developer like me to create, experiment, and enter areas that were previously inaccessible.

Codex did not just help me build ReviewTrace. It changed me from someone who accepts inconveniences into someone who tries to build solutions for them.

### What's next

I want to keep using Codex to build tools for problems and subjects that interest me.

I am already experimenting with a Morse code learning app and an app for learning Braille. They are more ambitious and not easy to build, but before Codex I would not have believed I could attempt them at all.

Next, I also want to test ReviewTrace with longer recordings, more iPhone models, and additional reviewers. I plan to measure Korean and English transcription quality before expanding to more speech languages.

ReviewTrace is a practical bridge for today's development workflow, and the lessons from building it will shape the tools I create next.

### Try it out

- [GitHub Repository](https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week)
- [Prebuilt Simulator Demo Release](https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week/releases/tag/build-week-demo)

## Conditional post-demo replacement — not part of the current Devpost description

실제 iPhone 녹화 처리, Codex 전달, UI 복구, 새 빌드 검증까지 성공한 뒤에는 `Accomplishments that I am proud of`의 첫 두 문단을 아래 문장으로 교체할 수 있습니다.

> I am proud that I used ReviewTrace to finish ReviewTrace itself. I reviewed the near-final app on a real iPhone, processed that recording with ReviewTrace, gave the resulting package to Codex, and used Codex to make the final visible improvement. The tool completed the same development loop it was created to support.

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
No credentials are required.

Demo video (public, under three minutes): https://youtu.be/X_OToLfUBK4
Public repository and README: https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week
Judge quick start: https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week/blob/main/Docs/JudgeQuickStart.md
Prebuilt universal Simulator app: https://github.com/woozy-A/ReviewTrace-OpenAI-Build-Week/releases/tag/build-week-demo

For the source path, open OpenAi_ReviewTrace.xcodeproj, select the shared ReviewTrace scheme, and run on an iOS 17+ iPhone Simulator. For the primary media path, use a privacy-safe 60–90 second portrait iPhone screen recording with microphone audio and select the actual spoken locale before import.
```

### Field `27951`: developer-tool installation and testing

```text
Platform: iPhone, iOS 17 or later. Verified toolchain: Xcode 26.6 (17F113). No login, server, API key, or package installation is required.

No-rebuild route: download ReviewTrace-Simulator.app.zip from the Build Week GitHub release, unzip it, boot an iOS 26.5 Simulator, then run:
xcrun simctl install <UDID> ReviewTrace.app
xcrun simctl launch <UDID> woozyLAB.ReviewTrace

Source route: open OpenAi_ReviewTrace.xcodeproj, select the shared ReviewTrace scheme, choose an iOS 17+ iPhone Simulator, and press Command-R. The root README contains unsigned generic-build and XCTest commands. The current suite contains 30 tests.

Primary workflow: Settings > App Language > English; Home > Language Spoken in This Review > English (en-US); import a narrated portrait screen recording; inspect Timeline > Readable; tap a timestamp to seek; inspect Codex > Direct Review Handoff; inspect Export > Share Review with Codex.

The Simulator route verifies the UI and judge path but is not claimed as real-device Apple Speech performance evidence. Version `1.0 (1)` was archived, exported with Apple Distribution signing, uploaded to App Store Connect, and processed for the connected internal TestFlight group. It is Ready to Test there, but TestFlight distribution does not replace real-device media verification. See Docs/Verification_2026-07-21.md for the exact boundary.
```

## Under-three-minute demo plan

Target length: **2:40–2:50**. Keep every actual product claim visible on screen. Cut loading and typing. The latest official announcement says a publicly accessible **unlisted** YouTube video is allowed; verify it while signed out.

If a friend records the English voiceover, use neutral narration such as “ReviewTrace was built…” or say once that they are narrating the creator's script. Add English subtitles, and keep the creator's real screen recording and product actions visible throughout.

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
- [x] Replace the `OWNER EDIT` placeholder with a personal sentence.
- [ ] Read the English description once and adjust any phrase that does not sound like the owner.
- [x] Choose a public repository and add the MIT license.
- [x] Rewrite the existing commit email to GitHub `noreply` before the first public push.
- [x] Authenticate GitHub CLI.
- [x] Create and push the public repository.
- [x] Upload `ReviewTrace-Simulator.app.zip` and its checksum as release assets.
- [ ] Record the privacy-safe real-iPhone sample and fill every `TBD` in `Samples/README.md`.
- [ ] Complete the ReviewTrace → Codex → repaired ReviewTrace proof before claiming it.
- [ ] Upload the final video to YouTube as public or unlisted, keep it under three minutes, and verify it while signed out.
- [ ] Run `/feedback` in the primary Codex task and copy the session ID.
- [ ] Replace every `OWNER_TODO_*` token in this document and the judge guide.
- [x] Upload the production app icon as the Devpost thumbnail.
- [ ] Add final product screenshots on Devpost.
- [x] Update Devpost project `1355065`, save it, and verify the project page.
- [ ] Submit—not only save as draft—and verify the green `Submitted` state before **2026-07-22 09:00 KST**.
