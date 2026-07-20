# ReviewTrace Technical Architecture

## Primary Architecture

The MVP architecture is imported-video post-processing:

1. User records with Apple's built-in Screen Recording and microphone ON.
2. User imports the resulting video into ReviewTrace.
3. ReviewTrace moves app-owned temporary imports, or copies externally selected files, into local app storage.
4. ReviewTrace reads duration and extracts or reads the video's audio track.
5. ReviewTrace splits extracted audio into small chunks.
6. ReviewTrace transcribes each chunk sequentially and saves each chunk transcript.
7. Transcript timestamps are offset back onto the original video timeline.
8. ReviewTrace builds the timeline, extracts readable-row frame previews on demand, and prepares direct Codex instructions, Markdown/JSON exports, and review package sharing.

An audio-file import follows the same chunk/transcript/export pipeline as a secondary workflow for development meetings or spoken reviews. Screen recordings remain the primary product flow and the source of truth for visual timestamp review.

The imported video is the source of truth. ReviewTrace must not record separate audio for MVP, because that would create sync risk.

## Non-MVP

Do not build these in the MVP:

- ReplayKit Broadcast Upload Extension
- Control Center widget or launcher
- Separate audio recorder
- Live transcription during recording
- Video overlay editor
- Issue extraction dashboard

These may return later after the imported-video MVP is validated.

## Main Target

### ReviewTrace

Main SwiftUI app target.

Responsibilities:

- Home and review list
- Video import through PhotosPicker or document picker fallback
- Local session storage
- Video preview with AVPlayer
- Audio extraction or audio-track transcription
- Timestamped timeline
- On-demand transformed video frames for readable timeline rows, held in a bounded memory cache
- Timestamp tap to seek video
- Direct Codex review instruction generation
- Markdown and JSON exports
- Share review package
- Korean-first UI with English option
- Secondary audio-file import
- Separate cancellable video optimization for Codex sharing

## Folder Layout

Local-first storage should use app documents:

```text
Documents/
  Sessions/
    <session-id>/
      recording.mov
      extractedAudio.m4a
      Chunks/
        chunk-000.m4a
        chunk-000-transcript.json
        chunk-001.m4a
        chunk-001-transcript.json
      transcript.json
      full-transcript.md
      readable-timeline.md
      original-timeline.md
      codex-prompt.md
      chatgpt-review.md
      review-data.json
      subtitles.srt
      subtitles.vtt
      codex-video-<generation>-01_<range>.mp4
```

## Data Models

MVP models:

- `ReviewSession`
- `TranscriptSegment`
- `AudioChunk`
- `ReviewProcessingSnapshot`
- `VideoCompressionSnapshot`
- `VideoCompressionPolicy`
- `ProcessingStatus`

Existing issue-related models can remain as future code only if they do not drive the MVP UI.

## Shared Processing Pipeline

```text
imported video/audio -> audio extraction/read -> audio chunks -> chunk transcription -> timestamp merge -> timeline grouping -> direct Codex instructions -> exports -> ReviewDetailView
```

Video optimization is intentionally separate:

```text
ready transcript -> user requests Codex package -> 540p transcode -> size check/split -> transactional install -> regenerate package documents
```

Transcription never waits for video compression. Cancelling or failing compression preserves the completed transcript and the previous successful optimized-video set.

Readable screen-recording rows request their frame from `VideoFrameExtractionService` at `segment.startTime`. Each request owns an `AVAssetImageGenerator`, applies the preferred track transform, uses bounded output and a small time tolerance, and normalizes task cancellation. `TimelineFrameCache` keys images by standardized video path and rounded decisecond. Frame failure is a neutral UI state and never blocks the transcript or timestamp seek.

## Transcription

Default locale: `ko-KR`.

Secondary locale: `en-US`.

Mock transcription may be used only for previews and isolated tests. Imported user videos must either produce real transcript segments or show a processing failure. The app must never replace a failed real transcription with sample review text, because that hides audio/timestamp problems.

The critical rule is that transcript timestamps must map to video time.

For imported videos, warm-up delay is `0`. Timeline `00:00` is the first frame/time of the imported recording.

Apple Speech chunks target 45 seconds. The boundary searches up to 5 seconds around that target for a quiet point, then exports later chunks with 1.5 seconds of overlap. The overlap protects words spoken across a cut; duplicate speech is removed during timeline merging. A chunk transcript stores chunk-local timestamps. Final timeline timestamps are calculated as:

```text
finalStartTime = chunk.startOffset + segment.startTime
finalEndTime = chunk.startOffset + segment.endTime
```

Completed chunk transcript files are reused on retry, so a failed chunk does not force the whole video to start over.

## Length Policy

- Recommended review length: 5-10 minutes.
- Normal support target: up to 30 minutes.
- Long review mode: up to 60 minutes.
- Over 60 minutes: allow import, but recommend splitting into multiple videos.

Do not block long videos only because they are long. Use chunking and progress UI instead.

## Export Policy

- Default Codex Work Package: includes recording media, `codex-prompt.md`, and `full-transcript.md`.
- Videos at or below 280,000,000 bytes use the original file. Larger videos require a separate user-started optimization job before package sharing.
- Optimized video policy: H.264, 960x540 landscape maximum (540x960 portrait), 30 fps, 2.7 Mbps video, 128 kbps audio, and 90% planning safety.
- If one optimized file could exceed 280,000,000 bytes, balanced time ranges are created and any oversized result is split again. Each package document includes the original-time range for every part.
- `full-transcript.md`: contains a readable timeline first and an original timeline second. It is not a summary or issue analysis.
- `codex-prompt.md`: a handoff prompt that tells Codex how to use the recording and full transcript. It can also explain optional JSON/timeline files when attached.
- `readable-timeline.md`: optional standalone timeline for humans.
- `original-timeline.md`: optional standalone timeline for timestamp verification and subtitles.
- `review-data.json`: structured developer/automation data with timeline rows, optional raw text, and processing snapshot.
- `subtitles.srt` and `subtitles.vtt`: optional subtitle exports for video players, editors, and web captions. They are not part of the default Codex handoff.

## Simulator vs Real Device

Simulator is useful for:

- UI
- Video import flow shape
- Mock transcript timeline
- AVPlayer detail screen
- Export generation

Real device is needed for:

- Importing real Photos screen recordings
- Apple Speech behavior with Korean audio
- Large video file memory/performance validation

## Privacy Architecture

ReviewTrace is local-first:

- No login required
- No upload by default
- User explicitly imports videos
- User explicitly shares exports
- Screen recordings may contain sensitive information
- No hidden recording
- No private APIs
- Imported files and generated documents stay in the app container until the user shares them
- Apple Speech recognition may use Apple services depending on device, language, and network; the app does not claim guaranteed on-device-only recognition
