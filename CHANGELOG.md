# Build Week changelog

## 2026-07-21

### Baseline preservation

- `4b90002` — captured the fresh Xcode project baseline before importing existing functionality.
- `fd356bb` — imported the working private ReviewTrace prototype as the explicit baseline. This is not claimed as greenfield Build Week work.

### Build Week implementation

- `befb088` — replaced analysis-first prompt generation with a direct Codex review handoff, added separate screen-recording/audio evidence rules, made Codex package sharing primary, and added prompt contract tests.
- `7d3a2e6` — added bounded, transformed, cancellable timestamp frame extraction with a decisecond in-memory cache and unit tests.
- `4f70285` — showed visual context only for readable screen-recording timeline rows while preserving audio/original layouts and timestamp seeking.
- Added the root setup, verification, sample protocol, privacy, limitation, and judge-path documentation.

### Verification at this point

- Generic iOS Debug compile: passed with signing disabled.
- iPhone 17 Pro Simulator, iOS 26.5: 22 XCTest cases passed, 0 failed.
- Real-iPhone narrated sample, processing benchmark, self-review before/after, Archive, and TestFlight: pending and not claimed as complete.
