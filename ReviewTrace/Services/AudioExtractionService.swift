@preconcurrency import AVFoundation
import Foundation

struct ExtractedAudioInfo: Hashable {
    let url: URL
    let duration: TimeInterval
    let fileSize: Int64
    let audioTrackCount: Int
    let formatDescription: String
}

enum AudioExtractionError: LocalizedError {
    case noAudioTrack(videoDuration: TimeInterval)
    case exportSessionUnavailable(videoDuration: TimeInterval, audioTrackCount: Int)
    case exportFailed(String)
    case exportedFileMissing(URL)
    case exportedFileEmpty(URL)
    case extractedAudioTooShort(videoDuration: TimeInterval, audioDuration: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .noAudioTrack(let videoDuration):
            "No audio track was found in the selected recording. videoDuration=\(ReviewTimeFormatter.clock(videoDuration))"
        case .exportSessionUnavailable(let videoDuration, let audioTrackCount):
            "Could not create an audio export session. videoDuration=\(ReviewTimeFormatter.clock(videoDuration)), audioTrackCount=\(audioTrackCount)"
        case .exportFailed(let message):
            "Audio export failed: \(message)"
        case .exportedFileMissing(let url):
            "Extracted audio file was not created at \(url.lastPathComponent)."
        case .exportedFileEmpty(let url):
            "Extracted audio file is empty at \(url.lastPathComponent)."
        case .extractedAudioTooShort(let videoDuration, let audioDuration):
            "Extracted audio is too short. videoDuration=\(ReviewTimeFormatter.clock(videoDuration)), audioDuration=\(ReviewTimeFormatter.clock(audioDuration))"
        }
    }
}

struct AudioExtractionService {
    func extractAudio(from videoURL: URL, to outputURL: URL) async throws -> ExtractedAudioInfo {
        let asset = AVAsset(url: videoURL)
        let videoDuration = try await seconds(for: asset)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let audioTrackCount = audioTracks.count
        let formatDescription = await formatSummary(for: audioTracks)

        guard !audioTracks.isEmpty else {
            throw AudioExtractionError.noAudioTrack(videoDuration: videoDuration)
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        do {
            try await export(asset: asset, to: outputURL, videoDuration: videoDuration, audioTrackCount: audioTrackCount)
        } catch {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            try await exportFallbackComposition(
                audioTracks: audioTracks,
                duration: CMTime(seconds: videoDuration, preferredTimescale: 600),
                to: outputURL,
                videoDuration: videoDuration,
                audioTrackCount: audioTrackCount,
                originalError: error
            )
        }

        let fileSize = try fileSize(at: outputURL)
        let extractedAsset = AVAsset(url: outputURL)
        let extractedDuration = try await seconds(for: extractedAsset)
        try validate(
            outputURL: outputURL,
            fileSize: fileSize,
            videoDuration: videoDuration,
            audioDuration: extractedDuration
        )

        return ExtractedAudioInfo(
            url: outputURL,
            duration: extractedDuration,
            fileSize: fileSize,
            audioTrackCount: audioTrackCount,
            formatDescription: formatDescription
        )
    }

    private func export(
        asset: AVAsset,
        to outputURL: URL,
        videoDuration: TimeInterval,
        audioTrackCount: Int
    ) async throws {
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExtractionError.exportSessionUnavailable(videoDuration: videoDuration, audioTrackCount: audioTrackCount)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        try await run(exportSession)
    }

    private func exportFallbackComposition(
        audioTracks: [AVAssetTrack],
        duration: CMTime,
        to outputURL: URL,
        videoDuration: TimeInterval,
        audioTrackCount: Int,
        originalError: Error
    ) async throws {
        let composition = AVMutableComposition()
        var insertedTrackCount = 0

        for sourceTrack in audioTracks {
            guard let targetTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                continue
            }

            do {
                try targetTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceTrack,
                    at: .zero
                )
                insertedTrackCount += 1
            } catch {
                continue
            }
        }

        guard insertedTrackCount > 0 else {
            throw AudioExtractionError.exportFailed("Could not insert any audio tracks into fallback composition. originalError=\(originalError.localizedDescription), videoDuration=\(ReviewTimeFormatter.clock(videoDuration)), audioTrackCount=\(audioTrackCount)")
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExtractionError.exportSessionUnavailable(videoDuration: videoDuration, audioTrackCount: audioTrackCount)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        try await run(exportSession)
    }

    private func run(_ exportSession: AVAssetExportSession) async throws {
        let exportBox = ExportSessionBox(exportSession)

        try await withCheckedThrowingContinuation { continuation in
            exportBox.session.exportAsynchronously {
                switch exportBox.session.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: AudioExtractionError.exportFailed(exportBox.session.error?.localizedDescription ?? "Unknown error"))
                default:
                    continuation.resume(throwing: AudioExtractionError.exportFailed("Unexpected export status \(exportBox.session.status.rawValue)"))
                }
            }
        }
    }

    private func validate(
        outputURL: URL,
        fileSize: Int64,
        videoDuration: TimeInterval,
        audioDuration: TimeInterval
    ) throws {
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw AudioExtractionError.exportedFileMissing(outputURL)
        }
        guard fileSize > 0 else {
            throw AudioExtractionError.exportedFileEmpty(outputURL)
        }
        guard audioDuration > 0 else {
            throw AudioExtractionError.extractedAudioTooShort(videoDuration: videoDuration, audioDuration: audioDuration)
        }

        let minimumExpectedDuration = videoDuration * 0.7
        if videoDuration > 30, audioDuration < minimumExpectedDuration {
            throw AudioExtractionError.extractedAudioTooShort(videoDuration: videoDuration, audioDuration: audioDuration)
        }
    }

    private func seconds(for asset: AVAsset) async throws -> TimeInterval {
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : 0
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func formatSummary(for audioTracks: [AVAssetTrack]) async -> String {
        var formatDescriptionCount = 0
        for track in audioTracks {
            let descriptions = (try? await track.load(.formatDescriptions)) ?? []
            formatDescriptionCount += descriptions.count
        }
        return "\(audioTracks.count) audio track(s), \(formatDescriptionCount) format description(s)"
    }
}

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
