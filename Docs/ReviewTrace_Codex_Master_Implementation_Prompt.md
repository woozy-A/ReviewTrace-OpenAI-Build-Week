# ReviewTrace — Codex Master Implementation Prompt

Paste this into the primary Codex thread after placing `ReviewTrace_OpenAI_Build_Week_Final_Plan.md` in the repository’s `Docs/` directory.

---

You are the primary implementation agent for the OpenAI Build Week version of ReviewTrace.

First, read this file completely:

```text
Docs/ReviewTrace_OpenAI_Build_Week_Final_Plan.md
```

Treat it as the current product and implementation authority. It supersedes older planning documents when they conflict.

## Product objective

ReviewTrace is an iPhone developer tool that preserves a human’s spoken app-review instructions at the exact screen-recording timestamps and hands the recording, transcript, and direct implementation instructions to Codex.

The final loop is:

```text
GPT-5.6 product planning
→ Codex implementation
→ human reviews the real iPhone app by speaking
→ ReviewTrace aligns speech with screen time
→ Codex modifies the repository
→ human verifies the result
```

Do not turn ReviewTrace into an AI issue summarizer. Do not add an OpenAI runtime API call.

## Existing behavior that must not regress

- screen-recording import;
- audio-file import;
- AVFoundation audio extraction;
- silence-aware chunking;
- Apple Speech transcription;
- chunk offset merge and duplicate reduction;
- progress, cancellation, persistence, and retry;
- readable/original timelines;
- timestamp tap to AVPlayer seek;
- Markdown, JSON, SRT, and VTT export;
- video optimization/splitting and range guidance;
- Korean/English UI.

## Required P0 work

### A. Direct Review Handoff

Update `ReviewTrace/Services/CodexPromptService.swift` so both short and long review paths use this contract:

1. video = source of truth for screen state and interaction flow;
2. timestamped transcript = source of truth for what the reviewer said;
3. repository = source of truth for implementation context;
4. human reviewer = final product decision;
5. inspect the matching video timestamp for “this,” “here,” “that button,” and similar references;
6. implement explicit requested changes directly;
7. do not convert praise, narration, or unresolved brainstorming into tasks;
8. later explicit corrections override earlier requests;
9. prefer the smallest safe change consistent with the existing design and architecture;
10. ask only when video + transcript + repository remain insufficient;
11. build/test after edits and report addressed timestamps, files, and verification.

Remove mandatory requests to first identify major issues, group comments, assign priority, or produce an issue summary.

Preserve split-video source-range instructions and audio-only behavior.

Add or update tests that verify the source contract appears and old analysis-first phrases no longer appear.

### B. Timestamp Visual Preview

Add:

```text
ReviewTrace/Services/VideoFrameExtractionService.swift
```

Use `AVAssetImageGenerator` to asynchronously generate a bounded thumbnail at a readable timeline row’s `startTime`.

Requirements:

- `appliesPreferredTrackTransform = true`;
- approximately 0.2-second tolerance before/after;
- in-memory cache keyed by video path + normalized timestamp;
- readable timeline and screen-recording sessions only;
- no thumbnail in original timeline mode;
- no thumbnail for audio-only sessions;
- placeholder/loading/failure state;
- cancellation during scrolling must not become a permanent failure;
- frame failure must never break transcript display or timestamp seek;
- tapping the row continues to seek the player.

Integrate this into the existing `TimelineTabView` and `TimelineRow` in `ReviewTrace/Views/ReviewDetailView.swift`. Do not add persistent frame data to `ReviewSession` for P0.

### C. Codex-first copy

Update localized copy in `ReviewTrace/App/ReviewTraceStore.swift` and the existing detail/export UI so the primary flow communicates:

- `Direct Review Handoff / 직접 리뷰 전달`;
- `Copy Review Instructions / 리뷰 지시문 복사`;
- `Share Review with Codex / Codex로 리뷰 전달`;
- package contents: recording, timestamp-aligned transcript, direct implementation instructions.

Keep the existing ChatGPT single-document export only as a secondary utility. Do not spend time removing working legacy exports unless they conflict with the main flow.

### D. Judge-ready documentation

Update or create the repository README with:

- what ReviewTrace does;
- why it is a Developer Tool;
- current architecture;
- supported iOS and Xcode versions;
- setup and run instructions;
- permissions;
- judge test path;
- sample narrated screen recording instructions;
- known limitations;
- privacy/local-first behavior;
- how GPT-5.6 and Codex were used;
- Build Week changelog with dated commits/features;
- dogfooding story: ReviewTrace reviewed and finished ReviewTrace.

Do not claim a greenfield build if the repository reused an earlier prototype. Use accurate wording from the plan’s project-history section.

## Working process

1. Inspect repository structure, project settings, and local instructions.
2. Create or confirm a dedicated Build Week branch.
3. Record the starting commit and current `git status`.
4. Run the current build and tests before editing.
5. Give a concise implementation plan mapped to actual files.
6. Continue into implementation; do not stop after planning unless a destructive ambiguity exists.
7. Implement one coherent stage at a time.
8. After each stage, run the relevant build/tests and make a focused commit.
9. Do not introduce a dependency unless there is no viable system-framework solution.
10. Do not raise the deployment target above iOS 17 unless required and explicitly justified.
11. Do not insert mock transcript results into real processing.
12. Do not perform a whole-app UI rewrite.
13. Keep changes small enough to review and revert.

## Recommended implementation order

### Commit 1 — Direct handoff

- refactor short and long Codex prompt generation;
- add prompt-contract tests;
- update primary Codex copy;
- run tests/build.

Suggested commit message:

```text
feat: replace analysis prompt with direct Codex review handoff
```

### Commit 2 — Visual preview service

- add frame extraction service;
- add memory cache;
- add unit-testable helpers where practical;
- run build.

Suggested commit message:

```text
feat: generate timestamped video frame previews
```

### Commit 3 — Timeline integration

- show previews in readable screen-recording timeline rows;
- preserve original/audio layouts and seek;
- verify on a vertical real recording;
- run build/tests.

Suggested commit message:

```text
feat: show screen context in readable review timeline
```

### Commit 4 — Submission readiness

- README and judge test path;
- sample-media notes;
- Build Week changelog;
- final copy polish;
- run full build/tests.

Suggested commit message:

```text
docs: add Build Week setup test path and workflow
```

### Commit 5 — Dogfooding fix

After the near-final build is reviewed through ReviewTrace, use the generated package to implement one visible final request.

Suggested commit message:

```text
refine: apply final ReviewTrace self-review feedback
```

## Implementation guidance

Use the code examples in the final plan as references. Adapt to the installed Xcode SDK; in particular, `AVAssetImageGenerator.image(at:)` may expose either a named or unnamed tuple depending on SDK overlays.

For preview integration, use `session.videoURL`, not `primaryMediaURL`, so an audio fallback is never treated as a video.

For P0, do not change the persistent `ReviewSession` schema to store thumbnail files. Generate readable-row previews on demand and cache them in memory.

For the direct handoff, retain `VideoPartTimelineGuide` and the existing media package. JSON schema changes are optional and must not delay visible P0 behavior.

## Acceptance tests before completion

- Import a real narrated screen recording.
- Verify real timestamped transcription.
- Verify readable/original toggle.
- Verify tap-to-seek.
- Verify at least five correctly oriented readable-row thumbnails.
- Verify audio-only and original timeline show no thumbnails.
- Verify thumbnail failure does not break timeline/seek.
- Verify short and long Codex prompts use the direct source contract.
- Verify all existing export URLs are still generated.
- Verify optimized/split video package still works.
- Use ReviewTrace to process a ReviewTrace self-review recording.
- Apply at least one visible request from that package in this repository.
- Build and run the final app on the target iPhone.

## Final report format

When implementation is complete, report:

```text
1. Summary of the finished user flow
2. Files changed by commit
3. New tests and their results
4. Full build result and target/device
5. Dogfooding review timestamps addressed
6. Any known limitations
7. Exact judge test steps
8. Final commit hashes
9. Reminder to run /feedback in this primary thread and save the Session ID
```

Start now with repository inspection, baseline build/tests, and Commit 1. Continue through the stages unless a concrete blocker requires my decision.
