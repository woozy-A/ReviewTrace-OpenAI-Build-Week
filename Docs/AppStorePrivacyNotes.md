# ReviewTrace App Store Privacy Notes

## Positioning

ReviewTrace is a user-controlled post-processing utility for app review workflows. The user imports a screen recording they already created with Apple's built-in Screen Recording. ReviewTrace processes the imported video locally by default and creates review exports.

## Data Handling

ReviewTrace may handle:

- Screen recording videos selected by the user
- Audio review or development meeting files selected by the user
- Audio tracks contained inside imported videos
- Speech recognition transcripts generated from those videos
- Local Markdown and JSON exports

The MVP does not directly record microphone audio and does not require login. Imported source files and generated exports stay in the app container until the user shares or deletes them. Speech recognition uses Apple's Speech framework and may use Apple services depending on device, language, and network conditions; ReviewTrace does not promise on-device-only recognition.

## User Control

- User explicitly records using iOS system Screen Recording.
- User explicitly imports a video into ReviewTrace.
- User explicitly shares generated exports.
- Sessions can be deleted.
- No hidden recording.
- No private APIs.

## Purpose Strings

`NSPhotoLibraryUsageDescription`

> ReviewTrace lets you import screen recordings to generate app review transcripts.

`NSSpeechRecognitionUsageDescription`

> ReviewTrace uses speech recognition to turn spoken app review feedback into a timestamped transcript.

## Sensitive Content Warning

Screen recordings may include sensitive personal, account, or product information. ReviewTrace should warn users to import only recordings they intend to review.
