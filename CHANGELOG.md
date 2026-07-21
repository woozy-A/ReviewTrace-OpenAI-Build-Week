# Build Week changelog

## 2026-07-21

### Baseline preservation

- `2bb12bb` — captured the fresh Xcode project baseline before importing existing functionality.
- `d176943` — imported the working private ReviewTrace prototype as the explicit baseline. This is not claimed as greenfield Build Week work.

### Build Week implementation

- `c3fa616` — replaced analysis-first prompt generation with a direct Codex review handoff, added separate screen-recording/audio evidence rules, made Codex package sharing primary, and added prompt contract tests.
- `9beabba` — added bounded, transformed, cancellable timestamp frame extraction with a decisecond in-memory cache and unit tests.
- `dc02c61` — showed visual context only for readable screen-recording timeline rows while preserving audio/original layouts and timestamp seeking.
- `5c0394c` — added independent per-review Korean/English Speech locale selection, persisted retry behavior, locale-safe transcript caches, and compatibility tests for existing reviews.
- `db91676` — finished the production UI polish by widening readable timeline previews to `84pt` and shortening the Direct Review Handoff helper copy.
- `91a378c` — moved app and permission copy into Apple String Catalogs, added live English/Korean display-language switching, and added localization regression tests.
- `da721e0` — aligned the default spoken-review language with the selected app language while preserving explicit per-review overrides.
- `76c1581` — added the final app icon, privacy manifest, release metadata, and TestFlight assets for version `1.0 (1)`.
- Added the root setup, verification, sample protocol, privacy, limitation, and judge-path documentation.

### Verification at this point

- Generic iOS Debug compile: passed with signing disabled.
- Final submission rerun on iPhone 17 Pro Simulator, iOS 26.3.1: 30 XCTest cases passed, 0 failed.
- iPhone 15 Pro, iOS 26.5.2: signed build, install, launch, and 22 XCTest cases passed.
- Korean and English app copy plus language-selection layouts were switched through the real Settings UI and visually checked on Simulator; real-English Apple Speech media processing still needs physical-device proof.
- The production source is frozen for filming; device and real-media verification remain separate. Any obvious before/after UI regression must be created only in a disposable demo branch and worktree.
- Signed Archive creation, Apple Distribution IPA export, App Store Connect upload, and TestFlight processing for `1.0 (1)`: complete.
- Latest-revision TestFlight installation, narrated sample, processing benchmark, and self-review before/after: pending and not claimed as complete.
