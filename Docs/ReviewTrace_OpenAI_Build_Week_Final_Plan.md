# ReviewTrace — OpenAI Build Week Final Product & Build Plan

> **Document status:** final product, implementation, demo, and submission plan  
> **Date:** 2026-07-21 KST  
> **Track:** Developer Tools  
> **Platform:** iPhone / iOS 17+  
> **Primary build tool:** Codex using GPT-5.6  
> **Source snapshot reviewed:** `ReviewTrace-GPT-Core-Code-2026-07-21.zip`  
> **Priority rule:** a smaller end-to-end build that works on a real iPhone is better than a broader unfinished build.

---

## 1. Product thesis

### One-sentence definition

**ReviewTrace lets a developer review a real iPhone app by speaking naturally, preserves each spoken instruction at the exact screen moment, and hands that context to Codex so it can modify the repository.**

### Korean definition

**ReviewTrace는 실제 iPhone 앱을 보며 말한 수정사항을 정확한 화면 시점과 연결해, Codex가 저장소에서 바로 수정할 수 있도록 전달하는 개발자 생산성 도구다.**

### Tagline

> **Review on iPhone. Fix with Codex.**

Supporting line:

> Talk through your app like you are speaking to a teammate. ReviewTrace preserves the screen moment and the spoken instruction for Codex.

### The product is not

- an AI issue summarizer;
- a meeting-notes app;
- an automatic UX judge;
- a replacement for Codex;
- a new screen recorder;
- a cloud-dependent transcription service.

ReviewTrace is the **human review interface** between a running product and a coding agent.

---

## 2. The real problem

Codex is already good at understanding instructions such as:

- “Make the green button at the top a little bigger.”
- “This title appears twice; keep only one.”
- “The tab bar should better match the current visual language.”
- “The selected state resets after I navigate back.”

The remaining friction is not translating those sentences into engineering jargon. The friction is preserving what the reviewer was seeing when they said them.

### Current workflow

```text
Codex builds the app
→ developer tests it on a real iPhone
→ developer notices a problem and speaks about it
→ developer later re-watches the recording
→ developer types the same request again
→ Codex modifies the repository
```

### ReviewTrace workflow

```text
Codex builds the app
→ developer tests it on a real iPhone while screen-recording with the microphone on
→ ReviewTrace imports the recording
→ ReviewTrace transcribes speech on the same media timeline
→ developer verifies the exact screen moment
→ ReviewTrace shares video + timestamped transcript + direct handoff instructions
→ Codex modifies the repository
→ developer verifies the result again
```

### Core insight

The iPhone screen recording already contains two synchronized sources:

```text
visual state and interaction flow → video track
spoken human instruction          → microphone audio track
```

ReviewTrace does not need to invent a new interpretation layer. It needs to preserve these sources and make them practical for Codex.

---

## 3. Target user and job to be done

### Primary user

An indie, student, or small-team app developer who:

- builds with Codex or another coding agent;
- frequently tests on a real iPhone;
- thinks faster by speaking than by writing issue tickets;
- notices UI, UX, navigation, state, and copy problems during use;
- does not want to manually document every screen and timestamp;
- wants to remain the final product reviewer.

### Job to be done

> When I test my app and explain changes out loud, preserve the screen and spoken context so Codex can act without making me describe the same problem twice.

---

## 4. Why this belongs in Developer Tools

ReviewTrace is an agentic development workflow tool. It connects:

- real-device testing;
- human product judgment;
- timestamped multimodal evidence;
- a coding agent operating inside the repository;
- build, test, and human verification.

It improves the final feedback loop of agent-assisted software development rather than automating the developer out of the loop.

---

## 5. Product roles and sources of truth

### Human reviewer

- decides what feels wrong or needs improvement;
- speaks naturally while using the app;
- resolves ambiguous product decisions;
- verifies the final result.

### ReviewTrace

- imports the screen recording;
- extracts and transcribes its audio;
- retains timestamps;
- lets the user jump between speech and screen state;
- prepares a direct, evidence-linked Codex handoff;
- does not replace the user’s words with AI-generated conclusions.

### Codex

- reads the target repository and its local instructions;
- reads the timestamped transcript;
- inspects the matching video moments;
- connects spoken references such as “this button” to actual components;
- implements explicit requests;
- builds and tests the result;
- asks a question only when the video, transcript, and repository still do not resolve ambiguity.

### Source-of-truth contract

```text
What was visible and how the app behaved → recording
What the reviewer actually said          → timestamped transcript
How the product is implemented           → repository
What should ultimately ship              → human reviewer
```

---

## 6. Product principles

### 6.1 Preserve, do not rewrite

The transcript is a record of the reviewer’s actual speech. Do not replace it with an AI summary or issue list.

### 6.2 Context before categorization

A timestamp and the corresponding screen state are more valuable than a guessed severity, label, or priority.

### 6.3 Chronology matters

A later explicit correction overrides an earlier instruction. Codex must consider the review as a sequence, not a bag of independent tickets.

### 6.4 Human reviews; Codex implements

ReviewTrace does not automatically decide what is good UX. It makes human product judgment easy to deliver.

### 6.5 Local-first core

The core workflow must work without an OpenAI runtime API call. Media processing, transcription, timeline generation, and export remain local to the device where supported by the existing implementation.

### 6.6 Honest failure

Never substitute mock transcript rows for failed processing. Show failure, preserve partial progress where available, and allow retry.

### 6.7 Demo truthfulness

The video must show the real app processing a real narrated recording. Do not present static sample cards as generated output.

---

## 7. Current implementation snapshot

The reviewed code snapshot already contains a substantial technical foundation.

### Media and session handling

- SwiftUI iPhone application;
- screen-recording and audio-file import;
- local session directories and persistence;
- session list, detail, deletion, retry, and bilingual copy;
- video optimization and splitting for large handoff files.

### Transcription pipeline

- AVFoundation audio extraction;
- Apple Speech transcription;
- silence-aware audio chunking;
- chunk overlap and duplicate reduction;
- offset merging back to the original recording timeline;
- progress snapshots and failed-chunk retry;
- readable and original transcript timelines.

### Review experience

- AVPlayer preview;
- timestamp tap to seek;
- readable/original timeline switch;
- Markdown, JSON, SRT, and VTT exports;
- Codex prompt and media package sharing.

### Important product gap

The current `CodexPromptService` asks Codex to first identify, group, and prioritize issues. That does not match the final product thesis. Codex can understand direct spoken requests when it receives the repository, recording, and aligned transcript.

The current timeline also requires a tap before the user can see the matching screen. A small visual preview can make the relationship between speech and screen immediately visible.

---

## 8. Final Build Week scope

The submission should add a coherent extension rather than broad new functionality.

# P0-A. Direct Review Handoff

Replace analysis-first Codex instructions with implementation-first instructions.

### Required behavior

The generated handoff must tell Codex to:

1. read repository instructions and inspect the existing architecture;
2. treat the recording as visual/interaction context;
3. treat the timestamped transcript as the reviewer’s spoken instruction record;
4. inspect the matching video moment for words such as “this,” “here,” or “that button”;
5. implement explicit requested changes directly;
6. ignore praise, narration, and unresolved brainstorming unless it contains a clear request;
7. apply later explicit corrections over earlier statements;
8. avoid turning every sentence into a ticket;
9. prefer the smallest change consistent with the existing design and architecture;
10. build and test after changes;
11. report which timestamps were addressed and what remains ambiguous.

### Direct handoff output set

The existing package is sufficient when it includes:

```text
recording.mov or optimized video parts
codex-prompt.md
full-transcript.md
review-data.json (optional structured reference)
```

No GPT-generated issue summary is required.

### Acceptance criteria

- The short and long prompt paths use the same source-of-truth rules.
- The prompt no longer asks for a mandatory issue summary, severity, or priority list before implementation.
- Split-video range guidance remains intact.
- Audio-only review behavior remains supported and does not claim visual evidence exists.
- Existing export and sharing flows continue to work.

---

# P0-B. Timestamp Visual Preview

Show the video frame corresponding to each **readable timeline row**.

### Why it matters

This is the clearest visual proof that ReviewTrace is not a generic transcription app:

```text
screen at 00:18 + “[00:18] Make this top green button larger.”
```

The frame preview is for human verification and demo clarity. Codex still receives the original recording and timestamped transcript.

### P0 behavior

- screen-recording sessions only;
- readable timeline only;
- frame generated at the row’s `startTime`;
- asynchronous extraction;
- preferred track transform applied;
- bounded thumbnail size;
- small time tolerance to improve extraction reliability;
- memory cache to prevent repeated extraction while scrolling;
- failure shows a neutral placeholder and never blocks transcript or seek;
- tapping the row still seeks the player to the same timestamp;
- audio-only and original-timeline modes keep their current layout.

### Acceptance criteria

- A 60–90 second vertical iPhone recording displays at least five correct readable-row previews.
- Orientation is correct.
- Scrolling does not continuously regenerate the same frames.
- A failed frame does not fail the review session.
- Audio-only sessions do not show image placeholders.
- Existing timestamp seek behavior remains correct.

---

# P0-C. Codex-first product copy and sharing

Do not redesign the entire app. Clarify the existing `Timeline / Codex / Export` structure.

### Recommended copy

| Current concept | Final copy |
|---|---|
| Codex Work Prompt | Direct Review Handoff |
| Copy Codex Prompt | Copy Review Instructions |
| Share Codex Work Package | Share Review with Codex |
| “Find UX/UI/bug issues” | “Use the recording and timeline to implement the reviewer’s explicit requests” |

### Included-content copy

- screen recording or optimized video parts;
- timestamp-aligned transcript;
- direct implementation instructions.

The existing ChatGPT single-document export may remain as a secondary utility. It must not dominate the main flow.

---

# P0-D. ReviewTrace reviews ReviewTrace

Use the near-final app to review itself and let Codex make the final visible changes.

### Required dogfooding flow

1. Run the near-final ReviewTrace build on a real iPhone.
2. Turn on iPhone screen recording and microphone.
3. Use ReviewTrace and speak two small, explicit final changes.
4. Import that recording into ReviewTrace.
5. Show the generated transcript, visual preview, and timestamp seek.
6. Share the package with the Codex session for the same repository.
7. Let Codex implement at least one visible request.
8. Build and run the updated app.
9. Show before/after in the submission video.

### Safe final-review requests

Choose changes that are visible but low-risk, for example:

- “The Share Review with Codex button is the main action, so make it a little more prominent.”
- “Make the timeline preview slightly wider so the screen context is easier to recognize.”
- “This helper text is too long; shorten it without changing the meaning.”

Avoid OS-version migrations, large navigation changes, persistence rewrites, or new dependencies during the final dogfooding pass.

---

# P0-E. Judge-ready test path

Because this is submitted as a Developer Tool, the repository must include:

- supported platform and minimum iOS version;
- Xcode version used;
- setup and run instructions;
- required privacy permissions;
- a small narrated sample screen recording;
- expected processing time for that sample;
- known limitations;
- a TestFlight link if it can be made stable in time;
- otherwise, a precise source-build test path and complete demo evidence.

TestFlight is preferred but must not block the working core and submission package.

---

## 9. Explicit non-goals for this deadline

Do not add:

- an OpenAI runtime API call;
- GPT-generated summaries or issue tickets;
- automatic severity or priority;
- automatic UI/component recognition;
- GitHub, Linear, or Notion integration;
- ReplayKit Broadcast Extension;
- direct repository modification from the iPhone app;
- team dashboards;
- a full information-architecture rewrite;
- a new transcription backend unless the existing one blocks the demo;
- persistent screenshot export unless all P0 items are finished.

These may be future directions, but each increases risk without improving the core 3-minute story.

---

## 10. User flow

### 10.1 Start

The user imports an iPhone screen recording that includes microphone audio.

### 10.2 Process

ReviewTrace:

1. validates media;
2. extracts audio;
3. chunks long audio;
4. transcribes each chunk;
5. merges timestamps onto the original recording timeline;
6. builds readable and original timelines;
7. prepares exports.

### 10.3 Verify

The user sees:

- recording preview;
- readable timeline with visual thumbnails;
- original timeline for exact transcript verification;
- tap-to-seek behavior.

### 10.4 Handoff

The user shares the video, transcript, and direct instructions to the Codex project session.

### 10.5 Complete the loop

Codex changes the repository, builds/tests it, and the user verifies the new build on the iPhone.

---

## 11. Technical architecture

```text
Media import
→ session creation and local persistence
→ audio extraction
→ silence-aware chunking
→ Apple Speech transcription
→ original-time offset merge
→ readable timeline builder
→ on-demand frame extraction and memory cache
→ direct Codex handoff generation
→ package share
→ Codex repository modification
→ build/test
→ human verification
```

### Existing files to preserve

```text
Shared/ReviewModels.swift
ReviewTrace/App/ReviewTraceStore.swift
ReviewTrace/Services/AudioExtractionService.swift
ReviewTrace/Services/AudioChunkingService.swift
ReviewTrace/Services/SpeechTranscriptionService.swift
ReviewTrace/Services/ReviewProcessingPipeline.swift
ReviewTrace/Services/TranscriptSegmentGrouper.swift
ReviewTrace/Services/ExportServices.swift
ReviewTrace/Services/CodexPromptService.swift
ReviewTrace/Views/ReviewDetailView.swift
```

### New file

```text
ReviewTrace/Services/VideoFrameExtractionService.swift
```

### Optional test file

```text
ReviewTraceTests/CodexPromptServiceTests.swift
ReviewTraceTests/VideoFrameExtractionServiceTests.swift
```

---

## 12. Implementation guidance and code examples

The following snippets are implementation guides. Codex must adapt them to the installed SDK and existing target membership rather than pasting blindly.

### 12.1 Video frame extraction

```swift
@preconcurrency import AVFoundation
import UIKit

struct VideoFrameExtractionService {
    var maximumSize = CGSize(width: 360, height: 640)
    var tolerance: TimeInterval = 0.20

    func frame(from videoURL: URL, at timestamp: TimeInterval) async throws -> UIImage {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize

        let toleranceTime = CMTime(seconds: tolerance, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = toleranceTime
        generator.requestedTimeToleranceAfter = toleranceTime

        let requestedTime = CMTime(
            seconds: max(0, timestamp),
            preferredTimescale: 600
        )

        // Current SDKs commonly return a named tuple.
        let result = try await generator.image(at: requestedTime)
        return UIImage(cgImage: result.image)
    }
}
```

If the installed SDK exposes an unnamed tuple, use:

```swift
let (cgImage, _) = try await generator.image(at: requestedTime)
return UIImage(cgImage: cgImage)
```

### 12.2 Memory cache

```swift
import UIKit

final class TimelineFrameCache {
    static let shared = TimelineFrameCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 48
        cache.totalCostLimit = 24 * 1_024 * 1_024
    }

    func image(videoURL: URL, timestamp: TimeInterval) -> UIImage? {
        cache.object(forKey: key(videoURL: videoURL, timestamp: timestamp))
    }

    func insert(_ image: UIImage, videoURL: URL, timestamp: TimeInterval) {
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        cache.setObject(
            image,
            forKey: key(videoURL: videoURL, timestamp: timestamp),
            cost: Int(pixels * 4)
        )
    }

    private func key(videoURL: URL, timestamp: TimeInterval) -> NSString {
        let decisecond = Int((timestamp * 10).rounded())
        return "\(videoURL.path)#\(decisecond)" as NSString
    }
}
```

### 12.3 SwiftUI frame preview

```swift
private struct TimelineFramePreview: View {
    let videoURL: URL
    let timestamp: TimeInterval

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var didFail = false

    private var taskID: String {
        "\(videoURL.path)#\(Int((timestamp * 10).rounded()))"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.secondary.opacity(0.10))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: didFail ? "photo.badge.exclamationmark" : "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: taskID) {
            guard image == nil, !isLoading else { return }

            if let cached = TimelineFrameCache.shared.image(
                videoURL: videoURL,
                timestamp: timestamp
            ) {
                image = cached
                return
            }

            isLoading = true
            didFail = false
            defer { isLoading = false }

            do {
                let generated = try await VideoFrameExtractionService().frame(
                    from: videoURL,
                    at: timestamp
                )
                TimelineFrameCache.shared.insert(
                    generated,
                    videoURL: videoURL,
                    timestamp: timestamp
                )
                image = generated
            } catch is CancellationError {
                // Scrolling may cancel the task. Do not display a permanent failure.
            } catch {
                didFail = true
            }
        }
    }
}
```

### 12.4 Pass preview context only in readable video mode

Conceptual change inside `TimelineTabView`:

```swift
let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
let isReadableMode = displayMode == .readable && !readableSegments.isEmpty
let displayedSegments = isReadableMode ? readableSegments : session.transcriptSegments
let previewVideoURL: URL? = (
    isReadableMode && session.resolvedSourceKind == .screenRecording
) ? session.videoURL : nil

ForEach(displayedSegments) { segment in
    TimelineRow(
        segment: segment,
        copy: copy,
        sourceKind: session.resolvedSourceKind,
        previewVideoURL: previewVideoURL
    ) {
        onSeek(segment.startTime)
    }
}
```

Conceptual row layout:

```swift
HStack(alignment: .top, spacing: 12) {
    if let previewVideoURL {
        TimelineFramePreview(
            videoURL: previewVideoURL,
            timestamp: segment.startTime
        )
    }

    // Existing timestamp, transcript, and play affordance remain.
}
```

Do not move frame generation into the persistent `ReviewSession` model for P0.

### 12.5 Direct Codex handoff prompt

The exact copy may be localized, but the contract should remain stable.

```swift
private func directReviewInstructions(
    for session: ReviewSession,
    readableTimeline: String,
    language: AppLanguage
) -> String {
    let rangeGuide = VideoPartTimelineGuide()
        .promptBlock(for: session, language: language)

    if language == .korean {
        return """
        현재 열려 있는 저장소의 앱을 수정해 주세요.

        첨부 자료는 하나의 실제 기기 리뷰입니다.
        - 영상은 화면 상태와 조작 흐름의 기준입니다.
        - 타임스탬프 전사는 리뷰어가 실제로 말한 내용의 기준입니다.
        - 저장소는 구현 맥락의 기준입니다.

        \(rangeGuide)

        작업 규칙:
        1. 저장소의 AGENTS.md, README, 로컬 지침과 현재 구조를 먼저 읽어 주세요.
        2. “여기”, “이 버튼”, “아까 화면” 같은 표현은 같은 타임스탬프의 영상을 확인한 뒤 해석해 주세요.
        3. 명확하게 요청된 수정은 직접 구현해 주세요.
        4. 칭찬, 화면 설명, 고민 중인 말은 자동으로 작업으로 만들지 마세요.
        5. 나중에 나온 명시적 정정은 앞선 요청보다 우선합니다.
        6. 기존 디자인과 아키텍처 안에서 가장 작고 안전한 변경을 우선해 주세요.
        7. 영상, 전사, 저장소를 확인해도 모호한 항목만 질문으로 남겨 주세요.
        8. 수정 후 빌드와 관련 테스트를 실행해 주세요.
        9. 완료 보고에는 대응한 타임스탬프, 변경 파일, 검증 결과를 포함해 주세요.

        읽기용 리뷰 타임라인:
        \(readableTimeline)
        """
    }

    return """
    Modify the app in the currently open repository using this real-device review.

    Treat the attachments as one review record:
    - The video is the source of truth for screen state and interaction flow.
    - The timestamped transcript is the source of truth for what the reviewer said.
    - The repository is the source of truth for implementation context.

    \(rangeGuide)

    Working rules:
    1. Read AGENTS.md, README, local instructions, and the existing architecture first.
    2. Resolve phrases such as “this,” “here,” and “that button” by inspecting the video at the same timestamp.
    3. Implement explicit requested changes directly.
    4. Do not turn praise, narration, or unresolved brainstorming into tasks.
    5. A later explicit correction overrides an earlier request.
    6. Prefer the smallest safe change consistent with the current design and architecture.
    7. Ask only about items that remain ambiguous after checking the video, transcript, and repository.
    8. Build and run relevant tests after editing.
    9. In the final report, map addressed timestamps to changed files and verification results.

    Readable review timeline:
    \(readableTimeline)
    """
}
```

The long-review path may omit embedding the whole transcript and instead direct Codex to `full-transcript.md`, but it must use the same rules.

### 12.6 Prompt tests

At minimum, add string-contract tests that verify:

```swift
func testKoreanPromptDefinesSourcesOfTruth() {
    let prompt = CodexPromptService().generate(for: sampleSession, language: .korean)
    XCTAssertTrue(prompt.contains("영상은 화면 상태와 조작 흐름의 기준"))
    XCTAssertTrue(prompt.contains("타임스탬프 전사"))
    XCTAssertTrue(prompt.contains("명확하게 요청된 수정은 직접 구현"))
}

func testPromptDoesNotRequireIssueSummary() {
    let prompt = CodexPromptService().generate(for: sampleSession, language: .english)
    XCTAssertFalse(prompt.contains("Identify the major issues"))
    XCTAssertFalse(prompt.contains("prioritized task list"))
}
```

Adapt fixtures to the project’s existing test construction.

---

## 13. Test matrix

### Regression

- import a screen recording;
- import an audio file;
- extract audio;
- process multiple chunks;
- retry a failed chunk;
- build readable timeline;
- tap timestamp to seek;
- generate all existing exports;
- optimize/split large video;
- persist and reopen a session.

### New feature

- vertical video preview orientation;
- preview at timestamp zero;
- preview near the end of the asset;
- repeated row display uses cache;
- cancellation during scroll does not become a permanent failure;
- corrupt or missing video produces a placeholder only;
- original timeline has no thumbnails;
- audio session has no thumbnails;
- Korean and English direct prompts contain the source contract;
- short and long review prompt paths preserve direct implementation rules.

### End-to-end

- process a real 60–90 second ReviewTrace self-review;
- verify at least two spoken requests against video timestamps;
- share the package;
- let Codex implement one visible change;
- build and run the changed app on the same iPhone.

---

## 14. Privacy and safety

Screen recordings may contain notifications, account details, private messages, and user content.

Required behavior and documentation:

- process only files explicitly selected by the user;
- keep runtime model/API upload out of the core path;
- explain microphone, photo-library, and speech-recognition permissions;
- let users delete sessions;
- preview what is included before sharing;
- use a clean demo device or recording without private information;
- do not include copyrighted music or third-party app material in the public demo unless permitted.

---

## 15. Project-history wording and rule-safe evidence

Release status and TestFlight status do not determine whether work existed before the submission period. Code history does.

Do not make project history the center of the pitch. Do keep the repository and submission accurate.

### Use the truthful variant

**Variant A — only the idea existed before Build Week:**

> The product concept was explored before Build Week, while the submitted implementation and working workflow were created during the submission period.

**Variant B — a private technical prototype/code existed:**

> ReviewTrace began as a private exploratory prototype. During Build Week, I turned it into a coherent Codex developer workflow by implementing the direct handoff, timestamp visual context, final product experience, testing, and self-review loop shown in this submission.

The reviewed source snapshot already contains working code, so Variant B is the safer statement if that code predates July 13. Do not claim a greenfield implementation if substantial code was reused.

### Evidence to preserve

- dated commits for every Build Week feature;
- one primary GPT-5.6 Codex session;
- `/feedback` session ID from that thread;
- a short Build Week changelog;
- a README section listing what was completed during the submission period;
- real demo footage of those additions working.

---

## 16. README structure

```text
# ReviewTrace

## What it does
## Why it exists
## Core workflow
## Build Week features
## Architecture
## How GPT-5.6 and Codex were used
## Supported platform
## Setup and run
## Judge test path
## Sample input
## Privacy
## Known limitations
## Build Week changelog
```

### Key README paragraph

> Codex is already capable of understanding natural product feedback and modifying a repository. ReviewTrace focuses on the missing input layer: preserving what a human said while looking at the real app, aligned to the exact screen moment. The Build Week workflow was planned with GPT-5.6, implemented and tested with Codex, then dogfooded by using ReviewTrace to review and finish ReviewTrace itself.

---

## 17. Three-minute demo production plan

### Creative thesis

Do not make a feature-tour video. Show a complete circular story:

> **Planned with GPT-5.6 → built with Codex → reviewed with ReviewTrace → finished with Codex.**

### Target duration

Aim for **2:40–2:50**, leaving safety margin below three minutes.

### Shot list

#### 0:00–0:18 — The missing loop

Visual:

- real iPhone running an app;
- developer notices a visible issue;
- quick cut to a long raw screen recording or retyping the feedback.

Narration:

> “Codex can already build and modify an app from natural language. But after I test the real app on my iPhone, I still have to explain the same feedback again.”

#### 0:18–0:32 — The idea

Visual:

- one product-plan page or Codex session;
- one quick code/build shot.

Narration:

> “I planned this human review loop with GPT-5.6 and used Codex to implement it in ReviewTrace.”

Do not dwell on chat history. The product must remain the focus.

#### 0:32–1:15 — Core app flow

Visual:

- import a 60–90 second narrated iPhone recording;
- processing progress;
- readable timestamped transcript;
- tap a row and seek to the exact screen moment;
- show the new visual frame previews.

Narration:

> “ReviewTrace extracts the spoken feedback from the same recording, keeps it aligned to the original video time, and shows the matching screen context beside each readable transcript row.”

#### 1:15–1:42 — Direct Codex handoff

Visual:

- Codex tab;
- direct instructions;
- export package contents;
- share/import into the target repository’s Codex session.

Narration:

> “It does not try to outsmart Codex with another issue summary. It preserves the human instruction, the exact timestamp, and the recording, then hands that context to Codex.”

#### 1:42–2:16 — ReviewTrace reviews itself

Visual:

- the reviewer speaks one or two final changes while using ReviewTrace;
- the recording is imported into ReviewTrace;
- the relevant transcript line and frame appear;
- package is delivered to Codex.

Narration:

> “For the final pass, I used ReviewTrace to review ReviewTrace itself, just as I would speak to a teammate.”

#### 2:16–2:38 — Codex finishes the app

Visual:

- Codex finds the relevant SwiftUI view;
- a concise diff or changed files;
- build/test success.

Narration:

> “Codex matched the spoken request to the real repository, made the change, and verified the build.”

#### 2:38–2:52 — Before/after and closing

Visual:

- before/after on the iPhone;
- final ReviewTrace screen;
- logo/title.

Narration:

> “We planned it with GPT-5.6, built it with Codex, reviewed it with ReviewTrace, and finished it with Codex. Review on iPhone. Fix with Codex.”

### Recording rules

- Use a clean demo device with no private notifications.
- Use a controlled 60–90 second source recording.
- Cut loading and typing time rather than speeding speech excessively.
- Voiceover must explicitly say how GPT-5.6 and Codex were used.
- Keep the YouTube video public or unlisted and verify it in a private browser window.
- No copyrighted music is needed.
- English narration is safest; add English subtitles if narration includes Korean app-review speech.

---

## 18. Submission copy draft

### Short description

> ReviewTrace turns a narrated iPhone app review into a timestamp-aligned handoff that Codex can use to modify the real repository.

### Longer description

> Codex is already good at understanding natural product feedback and changing code. The missing step appears after a human tests the real app: the developer must rewatch the recording and type the same feedback again. ReviewTrace imports an iPhone screen recording with microphone audio, transcribes the reviewer’s words on the original media timeline, and lets the developer jump from each spoken instruction to the exact screen moment. It then shares the recording, aligned transcript, and direct implementation instructions with Codex. Rather than replacing human judgment with another AI issue summary, ReviewTrace preserves the context Codex needs. The final Build Week version was dogfooded by using ReviewTrace to review and finish ReviewTrace itself.

### Closing line

> **Human judgment stays in the loop; ReviewTrace makes it actionable for Codex.**

Edit all submission prose into the creator’s own voice before posting.

---

## 19. Execution order and cut line

### Stage 1 — Freeze the baseline

- create/confirm the Build Week branch;
- record current commit;
- run current build and tests;
- preserve a short before-state screen recording.

### Stage 2 — Direct handoff

- update short and long Codex prompt paths;
- update product copy;
- add prompt contract tests;
- build and commit.

### Stage 3 — Visual preview

- add extraction service and cache;
- integrate readable timeline thumbnails;
- verify video orientation and failure behavior;
- build, test, and commit.

### Stage 4 — Judge readiness

- add sample media;
- write README setup/test instructions;
- prepare TestFlight if stable and time allows;
- retrieve `/feedback` session ID.

### Stage 5 — Dogfood and finish

- review the near-final app with ReviewTrace;
- hand the package to Codex;
- implement one visible final change;
- capture before/after;
- freeze the build.

### Stage 6 — Video and submission

- record narration and screen captures;
- edit to under three minutes;
- upload and verify link;
- submit repository, test path, README, session ID, and category;
- confirm the Devpost entry is submitted, not merely saved as a draft.

### Cut line

If time becomes critical, cut in this order:

1. persistent screenshot export;
2. JSON schema changes;
3. secondary UI polish;
4. TestFlight polish beyond a stable build;
5. all nonessential export formats.

Do **not** cut:

- real transcription;
- timestamp seek;
- direct handoff;
- at least one correct visual preview;
- self-review to Codex final change;
- README/test instructions;
- demo video and `/feedback` session ID.

---

## 20. Definition of done

The Build Week project is done when all of the following are true:

- [ ] A real iPhone screen recording with microphone audio imports successfully.
- [ ] Real speech is transcribed with original-video timestamps.
- [ ] Readable and original timelines are distinguishable.
- [ ] Tapping a transcript row seeks to the correct moment.
- [ ] Readable video rows show correctly oriented visual previews.
- [ ] Preview failure does not block the timeline.
- [ ] The Codex prompt uses direct review handoff rules rather than mandatory issue summarization.
- [ ] The package shares the recording, transcript, and instructions.
- [ ] ReviewTrace is used to review ReviewTrace.
- [ ] Codex implements at least one visible request from that review.
- [ ] The updated build runs on the target iPhone.
- [ ] Relevant tests pass.
- [ ] README contains setup, architecture, judge test path, and GPT-5.6/Codex collaboration.
- [ ] Dated commits and the primary `/feedback` session ID are preserved.
- [ ] The YouTube demo is under three minutes and viewable.
- [ ] The Devpost entry is fully submitted before the deadline.

---

## 21. Final product statement

> **Codex can write the code. A human still has to see the product. ReviewTrace lets that human review the real app by speaking naturally, preserves the exact screen context, and closes the loop back to Codex.**
