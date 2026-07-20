@preconcurrency import AVFoundation
import Foundation

enum AudioChunkingError: LocalizedError {
    case noAudioTrack(URL)
    case exportSessionUnavailable(Int)
    case exportFailed(index: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAudioTrack(let url):
            "No audio track was found in extracted audio file: \(url.lastPathComponent)."
        case .exportSessionUnavailable(let index):
            "Could not create export session for audio chunk \(index)."
        case .exportFailed(let index, let message):
            "Audio chunk \(index) export failed: \(message)"
        }
    }
}

struct AudioChunkingService {
    var chunkLength: TimeInterval = 45
    var overlap: TimeInterval = 1.5
    var minimumChunkDuration: TimeInterval = 5
    var silenceSearchRadius: TimeInterval = 5
    var silenceWindowDuration: TimeInterval = 0.35
    var silenceSampleInterval: TimeInterval = 0.25

    func makeChunks(from audioURL: URL, in sessionDirectory: URL) async throws -> [AudioChunk] {
        let chunksDirectory = try chunksDirectory(in: sessionDirectory)
        let asset = AVAsset(url: audioURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioChunkingError.noAudioTrack(audioURL)
        }

        let duration = try await asset.load(.duration)
        let totalDuration = CMTimeGetSeconds(duration)
        guard totalDuration.isFinite, totalDuration > 0 else {
            throw AudioExtractionError.extractedAudioTooShort(videoDuration: 0, audioDuration: 0)
        }

        let silenceAnalyzer = try? AudioSilenceAnalyzer(
            audioURL: audioURL,
            sampleInterval: silenceSampleInterval,
            windowDuration: silenceWindowDuration
        )
        var chunks: [AudioChunk] = []
        var logicalStartOffset: TimeInterval = 0
        var index = 0

        while logicalStartOffset < totalDuration {
            let remaining = totalDuration - logicalStartOffset
            guard remaining >= minimumChunkDuration || chunks.isEmpty else { break }

            let boundaryEnd = boundaryEndTime(
                logicalStartOffset: logicalStartOffset,
                totalDuration: totalDuration,
                silenceAnalyzer: silenceAnalyzer
            )
            let safeOverlap = index == 0 ? 0 : max(0, overlap)
            let exportStartOffset = max(0, logicalStartOffset - safeOverlap)
            let chunkDuration = max(0, boundaryEnd - exportStartOffset)
            let chunkURL = chunksDirectory
                .appendingPathComponent(String(format: "chunk-%03d", index))
                .appendingPathExtension("m4a")

            if await shouldExportChunk(at: chunkURL, expectedDuration: chunkDuration) {
                try removeCachedTranscript(index: index, chunksDirectory: chunksDirectory)
                try await exportChunk(
                    asset: asset,
                    audioTracks: audioTracks,
                    startOffset: exportStartOffset,
                    duration: chunkDuration,
                    index: index,
                    to: chunkURL
                )
            }

            chunks.append(
                AudioChunk(
                    url: chunkURL,
                    index: index,
                    startOffset: exportStartOffset,
                    duration: chunkDuration
                )
            )

            if boundaryEnd >= totalDuration || totalDuration - boundaryEnd < minimumChunkDuration {
                break
            }
            logicalStartOffset = boundaryEnd
            index += 1
        }

        return chunks
    }

    func chunksDirectory(in sessionDirectory: URL) throws -> URL {
        let url = sessionDirectory.appendingPathComponent("Chunks", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    func transcriptURL(for chunk: AudioChunk, in sessionDirectory: URL) throws -> URL {
        try chunksDirectory(in: sessionDirectory)
            .appendingPathComponent(String(format: "chunk-%03d-transcript", chunk.index))
            .appendingPathExtension("json")
    }

    private func exportChunk(
        asset: AVAsset,
        audioTracks: [AVAssetTrack],
        startOffset: TimeInterval,
        duration: TimeInterval,
        index: Int,
        to outputURL: URL
    ) async throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let composition = AVMutableComposition()
        let timeRange = CMTimeRange(
            start: CMTime(seconds: startOffset, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )

        var insertedTrackCount = 0
        for sourceTrack in audioTracks {
            guard let targetTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                continue
            }

            do {
                try targetTrack.insertTimeRange(timeRange, of: sourceTrack, at: .zero)
                insertedTrackCount += 1
            } catch {
                continue
            }
        }

        guard insertedTrackCount > 0 else {
            throw AudioChunkingError.exportFailed(index: index, message: "No audio tracks could be inserted into chunk composition.")
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioChunkingError.exportSessionUnavailable(index)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        let exportBox = ChunkExportSessionBox(exportSession)

        try await withCheckedThrowingContinuation { continuation in
            exportBox.session.exportAsynchronously {
                switch exportBox.session.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: AudioChunkingError.exportFailed(index: index, message: exportBox.session.error?.localizedDescription ?? "Unknown error"))
                default:
                    continuation.resume(throwing: AudioChunkingError.exportFailed(index: index, message: "Unexpected export status \(exportBox.session.status.rawValue)"))
                }
            }
        }

        guard (try? fileSize(at: outputURL)) ?? 0 > 0 else {
            throw AudioChunkingError.exportFailed(index: index, message: "Chunk file is empty.")
        }
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func boundaryEndTime(
        logicalStartOffset: TimeInterval,
        totalDuration: TimeInterval,
        silenceAnalyzer: AudioSilenceAnalyzer?
    ) -> TimeInterval {
        let desiredEnd = min(logicalStartOffset + chunkLength, totalDuration)
        guard desiredEnd < totalDuration else {
            return totalDuration
        }

        let minimumBoundary = min(totalDuration, logicalStartOffset + minimumChunkDuration)
        let maximumBoundary = max(
            minimumBoundary,
            min(totalDuration - minimumChunkDuration, desiredEnd + silenceSearchRadius)
        )
        let searchStart = max(minimumBoundary, desiredEnd - silenceSearchRadius)
        let searchEnd = max(searchStart, maximumBoundary)

        let selectedBoundary = silenceAnalyzer?.quietestBoundary(
            near: desiredEnd,
            from: searchStart,
            to: searchEnd
        ) ?? desiredEnd

        var boundary = min(max(selectedBoundary, minimumBoundary), maximumBoundary)
        if totalDuration - boundary < minimumChunkDuration {
            boundary = totalDuration
        }
        return boundary
    }

    private func shouldExportChunk(at url: URL, expectedDuration: TimeInterval) async -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              ((try? fileSize(at: url)) ?? 0) > 0 else {
            return true
        }

        let asset = AVAsset(url: url)
        guard let duration = try? await asset.load(.duration) else {
            return true
        }
        let seconds = CMTimeGetSeconds(duration)
        return !seconds.isFinite || abs(seconds - expectedDuration) > 0.35
    }

    private func removeCachedTranscript(index: Int, chunksDirectory: URL) throws {
        let transcriptURL = chunksDirectory
            .appendingPathComponent(String(format: "chunk-%03d-transcript", index))
            .appendingPathExtension("json")
        if FileManager.default.fileExists(atPath: transcriptURL.path) {
            try FileManager.default.removeItem(at: transcriptURL)
        }
    }
}

private final class ChunkExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}

private struct AudioSilenceAnalyzer {
    private struct EnergySample {
        var time: TimeInterval
        var rms: Float
    }

    private let samples: [EnergySample]
    private let silenceThreshold: Float
    private let windowDuration: TimeInterval

    init(audioURL: URL, sampleInterval: TimeInterval, windowDuration: TimeInterval) throws {
        let file = try AVAudioFile(forReading: audioURL)
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let framesPerSample = AVAudioFrameCount(max(1, sampleRate * sampleInterval))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerSample) else {
            self.samples = []
            self.silenceThreshold = 0
            self.windowDuration = windowDuration
            return
        }

        var collectedSamples: [EnergySample] = []
        while file.framePosition < file.length {
            let framePosition = file.framePosition
            let remainingFrames = AVAudioFrameCount(max(0, file.length - framePosition))
            let frameCount = min(framesPerSample, remainingFrames)
            guard frameCount > 0 else { break }

            try file.read(into: buffer, frameCount: frameCount)
            guard buffer.frameLength > 0 else { break }

            let time = TimeInterval(framePosition) / sampleRate
            collectedSamples.append(EnergySample(time: time, rms: Self.rms(buffer: buffer)))
        }

        self.samples = collectedSamples
        self.silenceThreshold = Self.silenceThreshold(for: collectedSamples.map(\.rms))
        self.windowDuration = windowDuration
    }

    func quietestBoundary(near target: TimeInterval, from start: TimeInterval, to end: TimeInterval) -> TimeInterval? {
        let candidates = samples.filter { sample in
            sample.time >= start && sample.time <= end
        }
        guard !candidates.isEmpty else { return nil }

        let quietCandidates = candidates.filter { $0.rms <= silenceThreshold }
        let pool = quietCandidates.isEmpty ? candidates : quietCandidates
        guard let selected = pool.min(by: { lhs, rhs in
            let lhsScore = score(sample: lhs, target: target, requiresQuietPenalty: quietCandidates.isEmpty)
            let rhsScore = score(sample: rhs, target: target, requiresQuietPenalty: quietCandidates.isEmpty)
            return lhsScore < rhsScore
        }) else {
            return nil
        }
        return selected.time + windowDuration / 2
    }

    private func score(sample: EnergySample, target: TimeInterval, requiresQuietPenalty: Bool) -> Double {
        let distanceScore = abs(sample.time - target)
        let energyScore = requiresQuietPenalty ? Double(sample.rms / max(silenceThreshold, 0.0001)) : 0
        return distanceScore + energyScore
    }

    private static func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return 0 }

        var sum: Float = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameCount {
                let value = samples[frame]
                sum += value * value
            }
        }

        return sqrt(sum / Float(frameCount * channelCount))
    }

    private static func silenceThreshold(for values: [Float]) -> Float {
        let sortedValues = values.filter { $0.isFinite && $0 > 0 }.sorted()
        guard !sortedValues.isEmpty else { return 0.003 }

        let quietFloor = percentile(0.2, values: sortedValues)
        let speechLevel = percentile(0.7, values: sortedValues)
        return max(0.003, min(0.04, max(quietFloor * 1.8, speechLevel * 0.18)))
    }

    private static func percentile(_ percentile: Double, values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        let clampedPercentile = min(max(percentile, 0), 1)
        let index = Int((Double(values.count - 1) * clampedPercentile).rounded())
        return values[index]
    }
}
