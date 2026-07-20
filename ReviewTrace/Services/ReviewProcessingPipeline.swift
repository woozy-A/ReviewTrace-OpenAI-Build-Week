@preconcurrency import AVFoundation
import Foundation

struct ReviewProcessingPipeline {
    var primaryTranscriptionService: SpeechTranscriptionServicing = SFSpeechRecognizerTranscriptionService()
    var markdownExportService = MarkdownExportService()
    var jsonExportService = JSONExportService()
    var subtitleExportService = SubtitleExportService()
    var codexPromptService = CodexPromptService()
    var audioExtractionService = AudioExtractionService()
    var audioChunkingService = AudioChunkingService()
    var transcriptGrouper = TranscriptSegmentGrouper()
    var transcriptCorrectionService = TranscriptCorrectionService()

    func process(
        _ session: ReviewSession,
        outputDirectory: URL,
        language: AppLanguage = AppConfiguration.defaultAppLanguage,
        progress: ((ReviewProcessingSnapshot) async -> Void)? = nil
    ) async -> ReviewSession {
        var working = session
        let sourceKind = working.resolvedSourceKind
        var collectedRawSegments: [TranscriptSegment] = []
        let startedAt = Date()
        var snapshot = ReviewProcessingSnapshot(
            sessionID: session.id,
            stage: sourceKind == .audioFile ? .importingAudio : .importingVideo,
            sourceKind: sourceKind,
            transcriptionLanguage: working.resolvedTranscriptionLanguage,
            startedAt: startedAt,
            updatedAt: startedAt
        )

        func publish(_ updatedSnapshot: ReviewProcessingSnapshot) async {
            await progress?(updatedSnapshot)
        }

        func updateSnapshot(_ mutate: (inout ReviewProcessingSnapshot) -> Void) async {
            mutate(&snapshot)
            snapshot.updatedAt = Date()
            working.processingSnapshot = snapshot
            await publish(snapshot)
        }

        working.status = .processing

        do {
            try Task.checkCancellation()
            let sourceDuration = await duration(for: working.primaryMediaURL)
            working.duration = max(working.duration, sourceDuration)
            await updateSnapshot {
                $0.stage = sourceKind == .audioFile ? .chunkingAudio : .extractingAudio
                $0.videoDuration = sourceDuration
            }

            try Task.checkCancellation()
            let audioInfo = try await audioURLForTranscription(session: working, outputDirectory: outputDirectory)
            working.micAudioURL = audioInfo.url
            await updateSnapshot {
                $0.stage = .chunkingAudio
                $0.extractedAudioDuration = audioInfo.duration
                $0.extractedAudioFileSize = audioInfo.fileSize
                $0.audioTrackCount = audioInfo.audioTrackCount
                $0.extractedAudioURL = audioInfo.url
            }

            try Task.checkCancellation()
            let chunks = try await audioChunkingService.makeChunks(from: audioInfo.url, in: outputDirectory)
            await updateSnapshot {
                $0.stage = .transcribingChunks
                $0.chunkCount = chunks.count
                $0.chunkURLs = chunks.map(\.url)
            }

            guard !chunks.isEmpty else {
                throw AudioChunkingError.noAudioTrack(audioInfo.url)
            }

            try Task.checkCancellation()
            guard await primaryTranscriptionService.requestAuthorization() else {
                throw SpeechTranscriptionError.authorizationDenied
            }

            for chunk in chunks {
                try Task.checkCancellation()
                await updateSnapshot {
                    $0.stage = .transcribingChunks
                    $0.currentChunkIndex = chunk.index
                    $0.failedChunkIndex = nil
                }

                do {
                    let localSegments = try await transcriptSegments(
                        for: chunk,
                        sessionDirectory: outputDirectory,
                        localeIdentifier: working.transcriptionLocaleIdentifier,
                        warmUpDelay: working.warmUpDelay
                    )
                    collectedRawSegments.append(contentsOf: applyOffset(to: localSegments, chunk: chunk))
                    await updateSnapshot {
                        $0.completedChunkCount += 1
                        $0.rawSegmentCount = collectedRawSegments.count
                    }
                } catch {
                    let groupedPartialSegments = transcriptCorrectionService.correct(transcriptGrouper.group(collectedRawSegments))
                    working.transcriptSegments = groupedPartialSegments
                    working.status = .failed
                    await updateSnapshot {
                        $0.stage = .failed
                        $0.failedChunkIndex = chunk.index
                        $0.lastError = error.localizedDescription
                        $0.rawSegmentCount = collectedRawSegments.count
                        $0.groupedTimelineRowCount = groupedPartialSegments.count
                    }
                    throw SpeechTranscriptionError.chunkFailed(index: chunk.index, message: error.localizedDescription)
                }
            }

            try Task.checkCancellation()
            await updateSnapshot {
                $0.stage = .mergingTranscript
                $0.currentChunkIndex = nil
                $0.rawSegmentCount = collectedRawSegments.count
            }

            let timelineSegments = transcriptCorrectionService.correct(transcriptGrouper.group(collectedRawSegments))
            guard !timelineSegments.isEmpty else {
                throw SpeechTranscriptionError.emptyResult
            }

            working.transcriptSegments = timelineSegments
            working.issueCandidates = []
            working.duration = max(working.duration, audioInfo.duration, timelineSegments.map(\.endTime).max() ?? 0)
            working.codexPrompt = codexPromptService.generate(for: working, language: language)
            await updateSnapshot {
                $0.stage = .creatingExports
                $0.groupedTimelineRowCount = timelineSegments.count
            }

            try Task.checkCancellation()
            _ = try jsonExportService.writeTranscript(session: working, to: outputDirectory)
            working.chatGPTReviewURL = try markdownExportService.writeChatGPTReview(session: working, to: outputDirectory, language: language)
            working.jsonURL = try jsonExportService.write(session: working, to: outputDirectory)
            working.codexBriefURL = try markdownExportService.writeCodexBrief(session: working, to: outputDirectory, language: language)
            working.readableTimelineURL = try markdownExportService.writeReadableTimeline(session: working, to: outputDirectory, language: language)
            working.originalTimelineURL = try markdownExportService.writeOriginalTimeline(session: working, to: outputDirectory, language: language)
            working.srtURL = try subtitleExportService.writeSRT(session: working, to: outputDirectory)
            working.vttURL = try subtitleExportService.writeVTT(session: working, to: outputDirectory)
            working.markdownURL = try markdownExportService.write(session: working, to: outputDirectory, language: language)
            working.status = .ready
            await updateSnapshot {
                $0.stage = .completed
                $0.completedChunkCount = chunks.count
                $0.currentChunkIndex = nil
                $0.failedChunkIndex = nil
                $0.lastError = nil
            }
        } catch is CancellationError {
            working.processingSnapshot = snapshot
            return working
        } catch {
            working.duration = max(working.duration, await duration(for: working.primaryMediaURL))
            working.issueCandidates = []
            working.status = .failed
            if working.transcriptSegments.isEmpty {
                working.transcriptSegments = transcriptCorrectionService.correct(transcriptGrouper.group(collectedRawSegments))
            }
            working.codexPrompt = failurePrompt(error, sourceKind: working.resolvedSourceKind)
            await updateSnapshot {
                $0.stage = .failed
                $0.lastError = error.localizedDescription
                $0.groupedTimelineRowCount = working.transcriptSegments.count
            }
        }

        working.processingSnapshot = snapshot
        return working
    }

    private func audioURLForTranscription(session: ReviewSession, outputDirectory: URL) async throws -> ExtractedAudioInfo {
        switch session.resolvedSourceKind {
        case .screenRecording:
            guard let videoURL = session.videoURL else { throw ReviewProcessingError.missingVideo }
            let extractedAudioURL = outputDirectory.appendingPathComponent("extractedAudio.m4a")
            return try await audioExtractionService.extractAudio(from: videoURL, to: extractedAudioURL)
        case .audioFile:
            guard let audioURL = session.micAudioURL else { throw ReviewProcessingError.missingAudio }
            return try await importedAudioInfo(for: audioURL)
        }
    }

    private func importedAudioInfo(for audioURL: URL) async throws -> ExtractedAudioInfo {
        let asset = AVAsset(url: audioURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioChunkingError.noAudioTrack(audioURL)
        }
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)

        return ExtractedAudioInfo(
            url: audioURL,
            duration: seconds.isFinite ? seconds : 0,
            fileSize: fileSize(at: audioURL),
            audioTrackCount: audioTracks.count,
            formatDescription: "\(audioTracks.count) audio track(s)"
        )
    }

    private func transcriptSegments(
        for chunk: AudioChunk,
        sessionDirectory: URL,
        localeIdentifier: String,
        warmUpDelay: TimeInterval
    ) async throws -> [TranscriptSegment] {
        let transcriptURL = try audioChunkingService.transcriptURL(
            for: chunk,
            in: sessionDirectory,
            localeIdentifier: localeIdentifier
        )
        // STUDY: Locale-specific caches keep an English retry from reusing Korean recognition results.
        var cacheCandidates = [transcriptURL]
        if localeIdentifier == AppConfiguration.defaultLanguageIdentifier {
            cacheCandidates.append(try audioChunkingService.legacyTranscriptURL(for: chunk, in: sessionDirectory))
        }

        for cachedURL in cacheCandidates where FileManager.default.fileExists(atPath: cachedURL.path) {
            do {
                let cachedSegments = try readChunkTranscript(at: cachedURL)
                if cachedURL != transcriptURL {
                    try writeChunkTranscript(cachedSegments, to: transcriptURL)
                }
                return cachedSegments
            } catch {
                try? FileManager.default.removeItem(at: cachedURL)
            }
        }

        try Task.checkCancellation()
        let localSegments = try await primaryTranscriptionService.transcribeAudio(
            at: chunk.url,
            localeIdentifier: localeIdentifier,
            contextualStrings: transcriptCorrectionService.contextualStrings,
            warmUpDelay: chunk.index == 0 ? warmUpDelay : 0,
            chunkIndex: chunk.index,
            timeout: 90
        )
        try writeChunkTranscript(localSegments, to: transcriptURL)
        return localSegments
    }

    private func applyOffset(to segments: [TranscriptSegment], chunk: AudioChunk) -> [TranscriptSegment] {
        segments.map { segment in
            TranscriptSegment(
                id: segment.id,
                startTime: max(0, chunk.startOffset + segment.startTime),
                endTime: max(0.5, chunk.startOffset + segment.endTime),
                text: segment.text,
                rawText: segment.rawText,
                confidence: segment.confidence,
                isIssueCandidate: false
            )
        }
    }

    private func readChunkTranscript(at url: URL) throws -> [TranscriptSegment] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TranscriptSegment].self, from: data)
    }

    private func writeChunkTranscript(_ segments: [TranscriptSegment], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(segments)
        try data.write(to: url, options: [.atomic])
    }

    private func failurePrompt(_ error: Error, sourceKind: ReviewSourceKind) -> String {
        let sourceChecks: String
        switch sourceKind {
        case .screenRecording:
            sourceChecks = """
            - 화면 녹화에서 마이크 오디오가 켜져 있었는지 확인하세요.
            - iOS 설정에서 음성 인식 권한이 허용되어 있는지 확인하세요.
            - 다시 가져왔을 때도 실패하면 영상 안에 오디오 트랙이 있는지 확인하세요.
            """
        case .audioFile:
            sourceChecks = """
            - 선택한 음성 파일에 실제 오디오 트랙이 있는지 확인하세요.
            - iOS 설정에서 음성 인식 권한이 허용되어 있는지 확인하세요.
            - 다시 가져왔을 때도 실패하면 다른 형식의 오디오 파일로 변환해 보세요.
            """
        }

        return """
        리뷰 처리에 실패했습니다.

        오류:
        \(error.localizedDescription)

        확인할 것:
        \(sourceChecks)
        """
    }

    private func duration(for url: URL?) async -> TimeInterval {
        guard let url else { return 0 }
        let asset = AVAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds.isFinite ? seconds : 0
        } catch {
            return 0
        }
    }

    private func fileSize(at url: URL) -> Int64 {
        let value = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? NSNumber
        return value?.int64Value ?? 0
    }
}

struct TranscriptCorrectionService {
    var glossary: TranscriptGlossary = .empty

    var contextualStrings: [String] {
        glossary.contextualTerms
    }

    func correct(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        segments.map(correct)
    }

    private func correct(_ segment: TranscriptSegment) -> TranscriptSegment {
        let rawText = segment.rawText ?? segment.text
        let correctedText = replacementRules.reduce(rawText) { currentText, rule in
            currentText.replacingOccurrences(
                of: rule.source,
                with: rule.replacement
            )
        }

        return TranscriptSegment(
            id: segment.id,
            startTime: segment.startTime,
            endTime: segment.endTime,
            text: correctedText,
            rawText: rawText,
            confidence: segment.confidence,
            isIssueCandidate: segment.isIssueCandidate
        )
    }

    private var replacementRules: [TranscriptReplacementRule] {
        TranscriptSafeCleanupRules.replacementRules + glossary.replacementRules
    }
}

struct TranscriptGlossary: Codable, Hashable {
    var contextualTerms: [String]
    var replacementRules: [TranscriptReplacementRule]

    static let empty = TranscriptGlossary(
        contextualTerms: [],
        replacementRules: []
    )
}

struct TranscriptReplacementRule: Codable, Hashable {
    var source: String
    var replacement: String
}

private enum TranscriptSafeCleanupRules {
    static let replacementRules = [
        TranscriptReplacementRule(source: "검색 창", replacement: "검색창"),
        TranscriptReplacementRule(source: "타임 라인", replacement: "타임라인"),
        TranscriptReplacementRule(source: "뒤로 가기", replacement: "뒤로가기"),
        TranscriptReplacementRule(source: "내 보내기", replacement: "내보내기")
    ]
}

private enum ReviewProcessingError: LocalizedError {
    case missingVideo
    case missingAudio

    var errorDescription: String? {
        switch self {
        case .missingVideo:
            "No video file was available for transcription."
        case .missingAudio:
            "No audio file was available for transcription."
        }
    }
}
