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
3. Open Control Center, long-press Screen Recording, and turn **Microphone On**.
4. Start recording and use ReviewTrace normally.
5. Speak the script below with a short pause between rows.
6. Stop recording, trim only dead time at the beginning or end, and keep the original audio/video synchronization.
7. Import the result into ReviewTrace and complete the expected-result checklist below.

## Suggested narration

These are safe prompts, not fixed timestamps. Replace the timestamp column with the measured values from the final recording.

| Measured time | Visual action | Spoken line |
| --- | --- | --- |
| TBD | Open the Home screen | “리뷰트레이스 홈 화면을 확인하고 있습니다.” |
| TBD | Start the import flow | “화면 녹화 가져오기 흐름으로 이동합니다.” |
| TBD | Return to a completed review | “완료된 리뷰에서 읽기용 타임라인을 확인합니다.” |
| TBD | Show a readable preview | “각 문장 옆 화면 미리보기로 당시 상황을 바로 확인할 수 있습니다.” |
| TBD | Show the Codex tab | “리뷰 지시문 복사 버튼의 설명을 조금 더 짧게 만들어 주세요.” |
| TBD | Show the Export tab | “Codex로 리뷰 전달이 주 작업이므로 이 버튼을 가장 눈에 띄게 유지해 주세요.” |

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
| Spoken locale | `ko-KR` |
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
| TBD | TBD | TBD | `ko-KR` | TBD | TBD | TBD | TBD |

Apple Speech availability and system/network conditions can affect processing time because on-device recognition is not required in the current build.

## Adding the final sample to Simulator Photos

After the real file is committed:

```sh
xcrun simctl addmedia <AVAILABLE_UDID> Samples/reviewtrace-narrated-self-review.mov
```

Simulator import is useful for a repeatable judge path, but it does not replace the required real-iPhone end-to-end proof.
