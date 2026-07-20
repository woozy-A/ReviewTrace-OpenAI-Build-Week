# ReviewTrace narrated sample

## Status

`reviewtrace-narrated-self-review.mov` is required for the final judge path but is **not yet committed**. It must be recorded on a real iPhone with the near-final ReviewTrace build. Do not replace the file with unrelated stock footage or describe Simulator media as real-device dogfooding.

## Required file

```text
Samples/reviewtrace-narrated-self-review.mov
```

Target characteristics:

- 60–90 seconds;
- vertical iPhone screen recording;
- microphone audio enabled;
- ReviewTrace itself visible throughout the review;
- at least six short spoken segments separated by two or three seconds of silence;
- at least two explicit, low-risk implementation requests;
- no personal information, notifications, copyrighted music, or third-party app content.

## Recording procedure

1. Install the near-final build on the target iPhone.
2. Enable Do Not Disturb and close screens that contain personal data.
3. Create one short completed seed review first; it supplies the Timeline and Export screens used in the final self-review.
4. Set **Settings → App Language → English** and **Home → Language Spoken in This Review → English (en-US)**.
5. Open Control Center, long-press Screen Recording, and turn **Microphone On**.
6. Start recording and follow [the exact screen route](../Docs/HackathonDemoRecordingGuide.md).
7. Speak the script below with a short pause between rows.
8. Stop recording, trim only dead time at the beginning or end, and keep the original audio/video synchronization.
9. Import the result with **English (en-US)** selected and complete the expected-result checklist below.

## Suggested narration

These are safe prompts, not fixed timestamps. Replace the timestamp column with the measured values from the final recording.

| Measured time | Visual action | Spoken line |
| --- | --- | --- |
| TBD | Open a completed review from **Reviews** | “I am opening a completed review.” |
| TBD | Open **Timeline → Readable** | “This is the readable timeline.” |
| TBD | Keep a left-side preview image visible | “Please make the preview image on the left a little wider.” |
| TBD | Open **Export** | “This is the Export screen.” |
| TBD | Keep **Direct Review Handoff** and its description visible | “Please shorten the description under Direct Review Handoff.” |
| TBD | Pause on the same card | “Please keep everything else unchanged.” |

The final two lines are the explicit implementation requests. A later sentence should correct an earlier one only if the demo intentionally proves the “later correction wins” rule.

## Metadata to fill after recording

| Field | Value |
| --- | --- |
| File name | `reviewtrace-narrated-self-review.mov` |
| SHA-256 | TBD |
| Recorded on | TBD |
| Device / iOS | TBD |
| Duration | TBD |
| File size | TBD |
| Orientation | Portrait |
| Spoken locale | `en-US` |
| Source | Owner-recorded ReviewTrace UI |

Compute the checksum after the final file is copied into this folder:

```sh
shasum -a 256 Samples/reviewtrace-narrated-self-review.mov
```

## Expected result

- The session reaches **Ready** without sample transcript fallback.
- The readable timeline contains at least five rows.
- Each readable screen-recording row shows a correctly oriented frame from its start time.
- Repeated scrolling reuses cached frames rather than continuously extracting them.
- Tapping a row seeks the player to the matching timestamp.
- Original timeline mode has no frame slots.
- An audio-only session has no image placeholders.
- The direct Codex package includes the recording or optimized parts, `full-transcript.md`, and `codex-prompt.md`.
- At least one of the two explicit requests is implemented by Codex and verified on the same iPhone.

## Processing benchmark

Measure from import confirmation until the session first reaches **Ready**. Run the same file three times on the target phone and record the range and median; do not infer them from Simulator or compile time.

| Device | iOS | Sample duration / size | Speech locale | Run 1 | Run 2 | Run 3 | Median |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TBD | TBD | TBD | `en-US` | TBD | TBD | TBD | TBD |

Apple Speech availability and system/network conditions can affect processing time because on-device recognition is not required in the current build.

## Adding the final sample to Simulator Photos

After the real file is committed:

```sh
xcrun simctl addmedia <AVAILABLE_UDID> Samples/reviewtrace-narrated-self-review.mov
```

Simulator import is useful for a repeatable judge path, but it does not replace the required real-iPhone end-to-end proof.
