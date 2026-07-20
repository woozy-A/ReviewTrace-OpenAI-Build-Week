# Build Week changelog

## 2026-07-21

### Baseline preservation

- `4b90002` — captured the fresh Xcode project baseline before importing existing functionality.
- `fd356bb` — imported the working private ReviewTrace prototype as the explicit baseline. This is not claimed as greenfield Build Week work.

### Build Week implementation

- `befb088` — replaced analysis-first prompt generation with a direct Codex review handoff, added separate screen-recording/audio evidence rules, made Codex package sharing primary, and added prompt contract tests.
- `7d3a2e6` — added bounded, transformed, cancellable timestamp frame extraction with a decisecond in-memory cache and unit tests.
- `4f70285` — showed visual context only for readable screen-recording timeline rows while preserving audio/original layouts and timestamp seeking.
- `51ad510` — added independent per-review Korean/English Speech locale selection, persisted retry behavior, locale-safe transcript caches, and compatibility tests for existing reviews.
- `b898558` — finished the production UI polish by widening readable timeline previews to `84pt` and shortening the Direct Review Handoff helper copy.
- Added the root setup, verification, sample protocol, privacy, limitation, and judge-path documentation.

### Verification at this point

- Generic iOS Debug compile: passed with signing disabled.
- iPhone 17 Pro Simulator, iOS 26.5: 25 XCTest cases passed, 0 failed.
- iPhone 15 Pro, iOS 26.5.2: signed build, install, launch, and 22 XCTest cases passed.
- Korean and English language-selection layouts were visually checked on Simulator; real-English Apple Speech media processing still needs physical-device proof.
- Production remains complete for filming; any obvious before/after UI regression must be created only in a disposable demo branch and worktree.
- Latest-revision physical-device run, narrated sample, processing benchmark, self-review before/after, Archive, and TestFlight: pending and not claimed as complete.
