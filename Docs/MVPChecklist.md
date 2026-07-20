# ReviewTrace MVP Checklist

## Product Direction

- [x] Post-processing app review tool direction documented.
- [x] Imported video is the source of truth.
- [x] No separate recording flow in MVP.
- [x] No embedded SDK approach.
- [x] Local-first privacy posture documented.

## Project Scaffold

- [x] Main iOS app target scaffolded.
- [x] Korean-first UI with English option.
- [x] Info.plist purpose strings for Photos and Speech.

## Models

- [x] `ReviewSession`
- [x] `TranscriptSegment`
- [x] Processing and video-compression status models.

## Main UI

- [x] HomeView with import-first CTA.
- [x] ImportVideoView and PhotosPicker import flow.
- [x] ProcessingView scaffold.
- [x] ReviewListView.
- [x] ReviewDetailView with video preview, Timeline, Codex, and Export.
- [x] Readable screen-recording rows show on-demand cached frame previews.
- [x] Original and audio-only timelines preserve their existing layout.
- [x] SettingsView with Korean/English app language switching.

## Processing

- [x] Mock data limited to previews and isolated UI development.
- [x] Speech transcription service boundary.
- [x] Audio extraction scaffold from imported video.
- [x] Imported video path uses warm-up delay 0.
- [x] Timeline timestamps seek the AVPlayer to the same time.
- [x] 45-second, silence-aware chunking with overlap deduplication.
- [x] Chunk transcript persistence and failed-chunk retry.
- [x] Separate video optimization progress, cancellation, and retry.

## Export

- [x] Markdown export service.
- [x] JSON export service.
- [x] Codex prompt service.
- [x] Direct implementation handoff contract for full and long-review prompt paths.
- [x] Share and copy UI.
- [x] Codex package is the primary share action; ChatGPT single-document export is secondary.
- [x] 540p Codex video optimization with 280 MB part limit.
- [x] Split-video range map in Codex prompt and transcript Markdown.

## Future, Not MVP

- [ ] AI issue extraction and grouping.
- [ ] Persistent screenshot extraction/export at timestamps. On-demand timeline frame previews are implemented.
- [ ] ReplayKit Broadcast Extension.
- [ ] Control Center launcher.
- [x] SRT/VTT subtitle export.

## Acceptance Criteria

- [x] App builds.
- [x] User can import a screen recording video.
- [x] App shows video player.
- [x] App shows transcript timeline.
- [x] Tapping timestamp seeks video.
- [x] App generates Codex prompt.
- [x] App exports Markdown.
- [x] App exports JSON.
- [x] App can share outputs.
- [x] No MVP screen asks the user to start a ReviewTrace broadcast.
- [x] Compression policy and timeline merging have XCTest coverage.
- [x] Direct prompt contract and frame cache/cancellation behavior have XCTest coverage.
