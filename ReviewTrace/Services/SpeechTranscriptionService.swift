import Foundation
import Speech

enum SpeechTranscriptionError: LocalizedError {
    case recognizerUnavailable(String)
    case authorizationDenied
    case emptyResult
    case chunkFailed(index: Int, message: String)
    case recognitionTimedOut(index: Int)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable(let locale):
            "Speech recognizer is unavailable for \(locale)."
        case .authorizationDenied:
            "Speech recognition permission was denied."
        case .emptyResult:
            "No speech transcription result was returned."
        case .chunkFailed(let index, let message):
            "Chunk \(index) transcription failed: \(message)"
        case .recognitionTimedOut(let index):
            "Chunk \(index) transcription timed out."
        }
    }
}

protocol SpeechTranscriptionServicing {
    func requestAuthorization() async -> Bool
    func transcribeAudio(
        at audioURL: URL,
        localeIdentifier: String,
        contextualStrings: [String],
        warmUpDelay: TimeInterval,
        chunkIndex: Int,
        timeout: TimeInterval
    ) async throws -> [TranscriptSegment]
}

struct SFSpeechRecognizerTranscriptionService: SpeechTranscriptionServicing {
    var requiresOnDeviceRecognition = false

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribeAudio(
        at audioURL: URL,
        localeIdentifier: String,
        contextualStrings: [String],
        warmUpDelay: TimeInterval,
        chunkIndex: Int,
        timeout: TimeInterval = 90
    ) async throws -> [TranscriptSegment] {
        try await withThrowingTaskGroup(of: [TranscriptSegment].self) { group in
            group.addTask {
                try await recognizeAudio(
                    at: audioURL,
                    localeIdentifier: localeIdentifier,
                    contextualStrings: contextualStrings,
                    warmUpDelay: warmUpDelay,
                    chunkIndex: chunkIndex
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw SpeechTranscriptionError.recognitionTimedOut(index: chunkIndex)
            }

            guard let result = try await group.next() else {
                throw SpeechTranscriptionError.emptyResult
            }
            group.cancelAll()
            return result
        }
    }

    private func recognizeAudio(
        at audioURL: URL,
        localeIdentifier: String,
        contextualStrings: [String],
        warmUpDelay: TimeInterval,
        chunkIndex: Int
    ) async throws -> [TranscriptSegment] {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), recognizer.isAvailable else {
            throw SpeechTranscriptionError.recognizerUnavailable(localeIdentifier)
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        request.contextualStrings = contextualStrings

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            var recognitionTask: SFSpeechRecognitionTask?

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if hasResumed {
                    return
                }

                if let error {
                    hasResumed = true
                    recognitionTask?.cancel()
                    if isNoSpeechError(error) {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: SpeechTranscriptionError.chunkFailed(index: chunkIndex, message: error.localizedDescription))
                    }
                    return
                }

                guard let result, result.isFinal else {
                    return
                }

                let segments = result.bestTranscription.segments.compactMap { transcriptionSegment -> TranscriptSegment? in
                    let adjustedStart = transcriptionSegment.timestamp - warmUpDelay
                    let adjustedEnd = transcriptionSegment.timestamp + transcriptionSegment.duration - warmUpDelay
                    guard adjustedEnd > 0 else { return nil }
                    return TranscriptSegment(
                        startTime: max(0, adjustedStart),
                        endTime: max(0.5, adjustedEnd),
                        text: transcriptionSegment.substring,
                        confidence: Double(transcriptionSegment.confidence)
                    )
                }

                hasResumed = true
                recognitionTask?.finish()
                continuation.resume(returning: segments)
            }
        }
    }

    private func isNoSpeechError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain", nsError.code == 1110 {
            return true
        }
        return nsError.localizedDescription.localizedCaseInsensitiveContains("no speech")
    }
}
