# ReviewTrace Product Vision

## One-line Description

ReviewTrace turns imported iPhone screen recordings into timestamped transcripts and Codex-ready app review notes.

## Product Direction

ReviewTrace is a post-processing app review tool.

The user records their iPhone screen with Apple's built-in Screen Recording, with microphone audio enabled. After recording, the user imports that video into ReviewTrace. The video file is the source of truth: ReviewTrace reads the audio track inside the video, transcribes it, keeps timestamps aligned to the video timeline, and exports review documents for Codex or ChatGPT.

ReviewTrace is not:

- A screen recording app
- A ReplayKit Broadcast Extension MVP
- An embedded SDK
- An in-app debug overlay
- A generic voice memo library
- A meeting transcription product as its primary identity

Importing an existing audio file is supported as a secondary utility. It lets a developer turn a spoken app review or development meeting into the same timestamped Codex handoff, without changing the primary screen-recording workflow.

## Core User Problem

When a developer tests an iOS app, they often record the screen and speak feedback naturally:

- "여기 버튼이 잘 안 보임"
- "이 화면은 너무 복잡함"
- "여기서 다음 화면으로 안 넘어감"
- "초보자는 이 용어를 이해 못 할 것 같음"

The recording already contains the most important review context, but the developer still has to rewrite the feedback manually before giving it to Codex or ChatGPT.

## Core Value

ReviewTrace converts an imported screen recording into:

- Timestamped transcript timeline
- Codex-ready prompt
- Markdown review document
- JSON structured export
- Shareable review package

Issue extraction, screenshot extraction, ReplayKit Broadcast Extension, and Control Center launchers are future features, not MVP scope.

## MVP User Flow

1. User records the iPhone screen with microphone ON.
2. User tests an app while speaking feedback.
3. User stops recording.
4. User opens ReviewTrace.
5. User imports the screen recording video.
6. ReviewTrace reads or extracts the video's audio track.
7. ReviewTrace transcribes speech into timestamped segments.
8. ReviewTrace shows video preview and transcript timeline.
9. User taps a timestamp to seek the video.
10. ReviewTrace generates Codex prompt, Markdown, and JSON exports.
11. User shares the review package.

For large recordings, transcript completion remains independent from video optimization. The user can read or share text immediately, then prepare cancellable 540p Codex video parts only when needed.

## Design Principle

Simple import. Clear timeline. Codex-ready export.

The app should feel like a clean utility: Photos video viewer, Notes, Voice Memos, and lightweight TestFlight feedback. It should not feel like a dashboard, video editor, social app, or AI chatbot.

## Language Direction

The app defaults to Korean so the primary builder can review and QA the product comfortably. English UI remains available through Settings for future users.

## MVP Acceptance Summary

The MVP is successful when the app builds, imports a screen recording video, shows an AVPlayer preview, generates a timestamped transcript timeline, seeks the video when a timeline row is tapped, generates a Codex prompt, exports Markdown and JSON, and shares the generated review package. No separate recording flow exists in the MVP.
