@preconcurrency import AVFoundation
import CoreVideo
import Foundation

struct MarkdownExportService {
    func write(session: ReviewSession, to directory: URL, language: AppLanguage = AppConfiguration.defaultAppLanguage) throws -> URL {
        let url = directory.appendingPathComponent("full-transcript.md")
        try makeMarkdown(for: session, language: language).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func writeCodexBrief(session: ReviewSession, to directory: URL, language: AppLanguage = AppConfiguration.defaultAppLanguage) throws -> URL {
        let url = directory.appendingPathComponent("codex-prompt.md")
        try CodexPromptService().generateBrief(for: session, language: language).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func writeChatGPTReview(session: ReviewSession, to directory: URL, language: AppLanguage = AppConfiguration.defaultAppLanguage) throws -> URL {
        let url = directory.appendingPathComponent("chatgpt-review.md")
        try makeChatGPTReview(for: session, language: language).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func writeReadableTimeline(session: ReviewSession, to directory: URL, language: AppLanguage = AppConfiguration.defaultAppLanguage) throws -> URL {
        let url = directory.appendingPathComponent("readable-timeline.md")
        try makeTimelineDocument(
            title: language == .korean ? "읽기용 타임라인" : "Readable Timeline",
            description: language == .korean
                ? "짧은 전사 행을 자연스럽게 묶고, 점 하나 같은 잡음은 제외한 사람이 읽기 좋은 타임라인입니다."
                : "A human-readable timeline with short rows grouped and punctuation-only noise removed.",
            segments: readableSegments(for: session),
            emptyText: language == .korean ? "생성된 읽기용 타임라인이 없습니다." : "No readable timeline rows were generated."
        ).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func writeOriginalTimeline(session: ReviewSession, to directory: URL, language: AppLanguage = AppConfiguration.defaultAppLanguage) throws -> URL {
        let url = directory.appendingPathComponent("original-timeline.md")
        try makeTimelineDocument(
            title: language == .korean ? "원문 타임라인" : "Original Timeline",
            description: language == .korean
                ? "전사 결과를 시간순으로 최대한 보존한 타임라인입니다. 자막, 시간 검증, 정확한 근거 확인에 사용하세요."
                : "A closer-to-original transcript timeline for subtitles, timestamp checks, and evidence review.",
            segments: session.transcriptSegments,
            emptyText: language == .korean ? "생성된 원문 타임라인이 없습니다." : "No original timeline rows were generated."
        ).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func makeMarkdown(for session: ReviewSession, language: AppLanguage = AppConfiguration.defaultAppLanguage) -> String {
        let readableSegments = readableSegments(for: session)
        let readableTimeline = timelineLines(readableSegments)
        let originalTimeline = timelineLines(session.transcriptSegments)
        let sourceKind = session.resolvedSourceKind
        let sourceFilename = session.primaryMediaURL?.lastPathComponent ?? (sourceKind == .audioFile ? "audioReview.m4a" : "recording.mov")
        let packageFilenames = session.codexPackageMediaURLs.map(\.lastPathComponent)
        let packageFilename = packageFilenames.first ?? sourceFilename
        let packageFilesDescription = packageFilenames.map { "`\($0)`" }.joined(separator: ", ")
        let videoPartGuide = VideoPartTimelineGuide().markdownSection(for: session, language: language)

        if language == .korean {
            let sourceDescription = sourceKind == .audioFile
                ? "이 파일은 음성 리뷰나 개발 회의 녹음에서 나온 발화를 시간순으로 옮긴 전체 전사입니다."
                : "이 파일은 화면 녹화에서 나온 음성 피드백을 시간순으로 옮긴 전체 전사입니다."
            let sourceInstruction = sourceKind == .audioFile
                ? "- Codex에 넣을 때는 음성 파일, `codex-prompt.md`, 이 파일을 함께 첨부하세요."
                : "- Codex에 넣을 때는 \(packageFilesDescription.isEmpty ? "`\(packageFilename)`" : packageFilesDescription) 영상, `codex-prompt.md`, 이 파일을 함께 첨부하세요."
            let sourceInfoTitle = sourceKind == .audioFile ? "음성 정보" : "영상 정보"
            let sourceFileLabel = sourceKind == .audioFile ? "음성 파일" : "파일"

            return """
            # 전체 전사 타임라인

            \(sourceDescription)
            요약이나 분석 결과가 아니라, Codex가 근거로 참고할 수 있도록 읽기용 타임라인과 원문 타임라인을 함께 제공합니다.

            ## 사용 방법

            \(sourceInstruction)
            - 자동화나 데이터 처리가 필요하면 `review-data.json`을 사용하세요.

            ## \(sourceInfoTitle)

            - \(sourceFileLabel): \(sourceFilename)
            - 날짜: \(ReviewTimeFormatter.markdownDate(session.createdAt))
            - 길이: \(ReviewTimeFormatter.clock(session.duration))
            - 타임라인 행 수: \(session.transcriptSegments.count)
            - 읽기용 행 수: \(readableSegments.count)

            \(videoPartGuide)

            ## 읽기용 타임라인

            짧은 전사 행을 자연스럽게 묶고, 점 하나 같은 잡음 행은 제외한 보기입니다.

            \(readableTimeline.isEmpty ? "생성된 전사 구간이 없습니다." : readableTimeline)

            ## 원문 타임라인

            전사 결과를 시간순으로 최대한 보존한 기록입니다.

            \(originalTimeline.isEmpty ? "생성된 전사 구간이 없습니다." : originalTimeline)
            """
        }

        let sourceDescription = sourceKind == .audioFile
            ? "This file is the full timestamped transcript extracted from an audio review or development meeting recording."
            : "This file is the full timestamped transcript extracted from the screen recording."
        let sourceInstruction = sourceKind == .audioFile
            ? "- When using Codex, attach the audio file, `codex-prompt.md`, and this file together."
            : "- When using Codex, attach \(packageFilesDescription.isEmpty ? "`\(packageFilename)`" : packageFilesDescription), `codex-prompt.md`, and this file together."
        let sourceInfoTitle = sourceKind == .audioFile ? "Audio Info" : "Video Info"
        let sourceFileLabel = sourceKind == .audioFile ? "Audio file" : "File"

        return """
        # Full Transcript Timeline

        \(sourceDescription)
        It is not a summary or analysis. It includes both a readable timeline and an original timeline for evidence.

        ## How to Use

        \(sourceInstruction)
        - For automation or structured processing, use `review-data.json`.

        ## \(sourceInfoTitle)

        - \(sourceFileLabel): \(sourceFilename)
        - Date: \(ReviewTimeFormatter.markdownDate(session.createdAt))
        - Duration: \(ReviewTimeFormatter.clock(session.duration))
        - Timeline rows: \(session.transcriptSegments.count)
        - Readable rows: \(readableSegments.count)

        \(videoPartGuide)

        ## Readable Timeline

        Short rows are merged for readability, and punctuation-only noise rows are removed.

        \(readableTimeline.isEmpty ? "No transcript segments were generated." : readableTimeline)

        ## Original Timeline

        This section preserves the timestamped transcript rows as closely as possible.

        \(originalTimeline.isEmpty ? "No transcript segments were generated." : originalTimeline)
        """
    }

    private func makeChatGPTReview(for session: ReviewSession, language: AppLanguage) -> String {
        let readableSegments = readableSegments(for: session)
        let readableTimeline = timelineLines(readableSegments)
        let originalTimeline = timelineLines(session.transcriptSegments)
        let sourceKind = session.resolvedSourceKind
        let sourceFilename = session.primaryMediaURL?.lastPathComponent
            ?? (sourceKind == .audioFile ? "audioReview.m4a" : "recording.mov")

        if language == .korean {
            let sourceNotice = sourceKind == .audioFile
                ? "음성 원본은 이 단일 문서에 포함되지 않았습니다. 아래 전사에서 확인되는 내용만 근거로 정리하고, 불명확한 부분은 추측하지 말고 질문으로 남겨 주세요."
                : "영상 원본은 이 단일 문서에 포함되지 않았습니다. 아래 전사에서 확인되는 내용만 근거로 정리하고, 화면 확인이 필요한 내용은 타임스탬프와 함께 표시해 주세요."
            let request = sourceKind == .audioFile
                ? """
                1. 회의 또는 음성 리뷰의 핵심 내용을 요약해 주세요.
                2. 결정된 내용, 미결정 사항, 추가 질문을 구분해 주세요.
                3. 반복되는 의견을 묶고 타임스탬프를 근거로 남겨 주세요.
                4. 개발자가 바로 실행할 수 있는 우선순위 작업 목록을 만들어 주세요.
                5. 마지막에는 Codex에 전달할 짧은 작업 지시문을 작성해 주세요.
                """
                : """
                1. 사용자가 말한 주요 UX/UI/버그 이슈를 정리해 주세요.
                2. 긍정적인 피드백과 반복되는 코멘트를 따로 묶어 주세요.
                3. 각 이슈에 타임스탬프를 근거로 표시해 주세요.
                4. 화면 확인이 더 필요한 부분은 단정하지 말고 확인 항목으로 남겨 주세요.
                5. 개발자가 바로 실행할 수 있는 우선순위 Codex 작업 목록을 만들어 주세요.
                """

            return """
            # ReviewTrace ChatGPT 전달 문서

            이 파일은 iPhone에서 ChatGPT로 한 번에 전달할 수 있도록 요청사항과 전체 전사를 합친 단일 문서입니다.
            \(sourceNotice)

            ## 리뷰 정보

            - 제목: \(session.title)
            - 원본 파일: \(sourceFilename)
            - 날짜: \(ReviewTimeFormatter.markdownDate(session.createdAt))
            - 길이: \(ReviewTimeFormatter.clock(session.duration))
            - 읽기용 타임라인 행 수: \(readableSegments.count)
            - 원문 타임라인 행 수: \(session.transcriptSegments.count)

            ## 요청

            \(request)

            ## 읽기용 타임라인

            \(readableTimeline.isEmpty ? "생성된 전사 구간이 없습니다." : readableTimeline)

            ## 원문 타임라인

            \(originalTimeline.isEmpty ? "생성된 원문 타임라인이 없습니다." : originalTimeline)
            """
        }

        let sourceNotice = sourceKind == .audioFile
            ? "The original audio is not included in this single document. Use only the transcript as evidence and leave unclear points as questions rather than guessing."
            : "The original video is not included in this single document. Use only the transcript as evidence and mark anything that needs visual confirmation with its timestamp."
        let request = sourceKind == .audioFile
            ? """
            1. Summarize the meeting or spoken review.
            2. Separate decisions, unresolved items, and follow-up questions.
            3. Group repeated comments and preserve timestamps as evidence.
            4. Produce a prioritized implementation task list.
            5. End with a short work instruction that can be handed to Codex.
            """
            : """
            1. Identify the UX, UI, and bug issues mentioned by the reviewer.
            2. Separate positive feedback from repeated concerns.
            3. Preserve timestamps as evidence for each issue.
            4. Leave anything requiring visual confirmation as a verification item.
            5. Produce a prioritized Codex implementation task list.
            """

        return """
        # ReviewTrace ChatGPT Handoff

        This single file combines the request and full transcript for sharing to ChatGPT from iPhone.
        \(sourceNotice)

        ## Review Info

        - Title: \(session.title)
        - Source file: \(sourceFilename)
        - Date: \(ReviewTimeFormatter.markdownDate(session.createdAt))
        - Duration: \(ReviewTimeFormatter.clock(session.duration))
        - Readable timeline rows: \(readableSegments.count)
        - Original timeline rows: \(session.transcriptSegments.count)

        ## Request

        \(request)

        ## Readable Timeline

        \(readableTimeline.isEmpty ? "No transcript segments were generated." : readableTimeline)

        ## Original Timeline

        \(originalTimeline.isEmpty ? "No original timeline was generated." : originalTimeline)
        """
    }

    private func makeTimelineDocument(title: String, description: String, segments: [TranscriptSegment], emptyText: String) -> String {
        let timeline = timelineLines(segments)
        return """
        # \(title)

        \(description)

        \(timeline.isEmpty ? emptyText : timeline)
        """
    }

    private func readableSegments(for session: ReviewSession) -> [TranscriptSegment] {
        let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
        return readableSegments.isEmpty ? session.transcriptSegments : readableSegments
    }

    private func timelineLines(_ segments: [TranscriptSegment]) -> String {
        segments.map { segment in
            "[\(ReviewTimeFormatter.clock(segment.startTime))] \(segment.text)"
        }.joined(separator: "\n")
    }
}

struct VideoCompressionPolicy: Hashable {
    static let codex = VideoCompressionPolicy(
        maximumPartSize: 280_000_000,
        targetVideoBitRate: 2_700_000,
        targetAudioBitRate: 128_000,
        targetFrameRate: 30,
        targetLandscapeWidth: 960,
        targetLandscapeHeight: 540,
        planningSafetyRatio: 0.90
    )

    var maximumPartSize: Int64
    var targetVideoBitRate: Int
    var targetAudioBitRate: Int
    var targetFrameRate: Int32
    var targetLandscapeWidth: Double
    var targetLandscapeHeight: Double
    var planningSafetyRatio: Double

    func requiresCompression(fileSize: Int64) -> Bool {
        fileSize > maximumPartSize
    }

    func maximumPlannedPartDuration(hasAudio: Bool) -> TimeInterval {
        let audioBitRate = hasAudio ? targetAudioBitRate : 0
        let totalBitRate = Double(targetVideoBitRate + audioBitRate)
        let safetyAdjustedBits = Double(maximumPartSize) * 8 * planningSafetyRatio
        return max(60, safetyAdjustedBits / totalBitRate)
    }

    func plannedPartCount(duration: TimeInterval, hasAudio: Bool) -> Int {
        guard duration > 0 else { return 0 }
        return max(1, Int(ceil(duration / maximumPlannedPartDuration(hasAudio: hasAudio))))
    }

    func balancedPartDuration(duration: TimeInterval, hasAudio: Bool) -> TimeInterval {
        let count = plannedPartCount(duration: duration, hasAudio: hasAudio)
        return count > 0 ? duration / Double(count) : 0
    }
}

struct VideoCompressionService {
    var policy: VideoCompressionPolicy = .codex

    private var targetLandscapeSize: CGSize {
        CGSize(width: policy.targetLandscapeWidth, height: policy.targetLandscapeHeight)
    }

    func writeCodexPreviewsIfNeeded(
        session: ReviewSession,
        to directory: URL,
        force: Bool = false,
        progress: (@Sendable (VideoCompressionSnapshot) -> Void)? = nil
    ) async throws -> [OptimizedVideoPart] {
        guard session.resolvedSourceKind == .screenRecording,
              let sourceURL = session.videoURL else {
            return []
        }

        let sourceSize = fileSize(at: sourceURL)
        let asset = AVURLAsset(url: sourceURL)
        let duration = await duration(for: asset)
        guard force || policy.requiresCompression(fileSize: sourceSize) else {
            return []
        }
        guard duration > 0 else {
            throw VideoCompressionError.invalidDuration
        }

        try Task.checkCancellation()
        progress?(
            VideoCompressionSnapshot(
                sessionID: session.id,
                stage: .preparing,
                progress: 0.01
            )
        )

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw VideoCompressionError.missingVideoTrack
        }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first
        let assetDuration = try await asset.load(.duration)
        let renderPlan = try await renderPlan(for: videoTrack)

        let plannedPartCount = policy.plannedPartCount(duration: duration, hasAudio: audioTrack != nil)
        let balancedPartDuration = duration / Double(plannedPartCount)
        let stagingDirectory = directory.appendingPathComponent(".codex-video-staging-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: stagingDirectory)
        }
        var drafts: [OptimizedVideoDraft] = []

        do {
            for partIndex in 0..<plannedPartCount {
                try Task.checkCancellation()
                let startTime = Double(partIndex) * balancedPartDuration
                let partDuration = partIndex == plannedPartCount - 1
                    ? duration - startTime
                    : balancedPartDuration
                let timeRange = CMTimeRange(
                    start: CMTime(seconds: startTime, preferredTimescale: 600),
                    duration: CMTime(seconds: partDuration, preferredTimescale: 600)
                )
                let encodedDrafts = try await encodeWithinSizeLimit(
                    asset: asset,
                    videoTrack: videoTrack,
                    audioTrack: audioTrack,
                    assetDuration: assetDuration,
                    timeRange: timeRange,
                    renderPlan: renderPlan,
                    directory: stagingDirectory,
                    progress: { localProgress in
                        let completedFraction = Double(partIndex) / Double(plannedPartCount)
                        let currentFraction = localProgress / Double(plannedPartCount)
                        progress?(
                            VideoCompressionSnapshot(
                                sessionID: session.id,
                                stage: .compressing,
                                progress: 0.03 + min(0.90, (completedFraction + currentFraction) * 0.90),
                                currentPartIndex: partIndex,
                                plannedPartCount: plannedPartCount,
                                completedPartCount: partIndex
                            )
                        )
                    }
                )
                drafts.append(contentsOf: encodedDrafts)
                progress?(
                    VideoCompressionSnapshot(
                        sessionID: session.id,
                        stage: .compressing,
                        progress: 0.03 + (Double(partIndex + 1) / Double(plannedPartCount)) * 0.90,
                        currentPartIndex: partIndex,
                        plannedPartCount: plannedPartCount,
                        completedPartCount: partIndex + 1,
                        producedPartCount: drafts.count
                    )
                )
            }

            try Task.checkCancellation()
            progress?(
                VideoCompressionSnapshot(
                    sessionID: session.id,
                    stage: .installing,
                    progress: 0.96,
                    plannedPartCount: plannedPartCount,
                    completedPartCount: plannedPartCount,
                    producedPartCount: drafts.count
                )
            )
            let stagedParts = try finalize(
                drafts: drafts.sorted { $0.startTime < $1.startTime },
                in: stagingDirectory
            )
            let installedParts = try install(stagedParts: stagedParts, in: directory)
            progress?(
                VideoCompressionSnapshot(
                    sessionID: session.id,
                    stage: .completed,
                    progress: 1,
                    plannedPartCount: plannedPartCount,
                    completedPartCount: plannedPartCount,
                    producedPartCount: installedParts.count
                )
            )
            return installedParts
        } catch {
            throw error
        }
    }

    private func encodeWithinSizeLimit(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        audioTrack: AVAssetTrack?,
        assetDuration: CMTime,
        timeRange: CMTimeRange,
        renderPlan: VideoRenderPlan,
        directory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [OptimizedVideoDraft] {
        try Task.checkCancellation()
        let outputURL = directory
            .appendingPathComponent("codex-video-work-\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        try await transcode(
            asset: asset,
            videoTrack: videoTrack,
            audioTrack: audioTrack,
            assetDuration: assetDuration,
            timeRange: timeRange,
            renderPlan: renderPlan,
            outputURL: outputURL,
            progress: progress
        )

        let outputSize = fileSize(at: outputURL)
        guard outputSize > 0 else {
            throw VideoCompressionError.emptyOutput
        }

        let startTime = CMTimeGetSeconds(timeRange.start)
        let duration = CMTimeGetSeconds(timeRange.duration)
        guard outputSize > policy.maximumPartSize else {
            return [
                OptimizedVideoDraft(
                    url: outputURL,
                    startTime: startTime,
                    duration: duration,
                    fileSize: outputSize
                )
            ]
        }

        try FileManager.default.removeItem(at: outputURL)
        guard duration > 60 else {
            throw VideoCompressionError.couldNotMeetFileSizeLimit(outputSize)
        }

        let firstDuration = duration / 2
        let firstRange = CMTimeRange(
            start: timeRange.start,
            duration: CMTime(seconds: firstDuration, preferredTimescale: 600)
        )
        let secondRange = CMTimeRange(
            start: CMTimeAdd(timeRange.start, firstRange.duration),
            duration: CMTime(seconds: duration - firstDuration, preferredTimescale: 600)
        )

        let firstDrafts = try await encodeWithinSizeLimit(
            asset: asset,
            videoTrack: videoTrack,
            audioTrack: audioTrack,
            assetDuration: assetDuration,
            timeRange: firstRange,
            renderPlan: renderPlan,
            directory: directory,
            progress: progress
        )
        let secondDrafts = try await encodeWithinSizeLimit(
            asset: asset,
            videoTrack: videoTrack,
            audioTrack: audioTrack,
            assetDuration: assetDuration,
            timeRange: secondRange,
            renderPlan: renderPlan,
            directory: directory,
            progress: progress
        )
        return firstDrafts + secondDrafts
    }

    private func transcode(
        asset: AVAsset,
        videoTrack: AVAssetTrack,
        audioTrack: AVAssetTrack?,
        assetDuration: CMTime,
        timeRange: CMTimeRange,
        renderPlan: VideoRenderPlan,
        outputURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try Task.checkCancellation()
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange

        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: [videoTrack],
            videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]
        )
        videoOutput.alwaysCopiesSampleData = false
        videoOutput.videoComposition = makeVideoComposition(
            videoTrack: videoTrack,
            assetDuration: assetDuration,
            renderPlan: renderPlan
        )
        guard reader.canAdd(videoOutput) else {
            throw VideoCompressionError.readerConfigurationFailed
        }
        reader.add(videoOutput)

        var audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack {
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM]
            )
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else {
                throw VideoCompressionError.audioReaderConfigurationFailed
            }
            reader.add(output)
            audioOutput = output
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(renderPlan.renderSize.width),
                AVVideoHeightKey: Int(renderPlan.renderSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: policy.targetVideoBitRate,
                    AVVideoExpectedSourceFrameRateKey: Int(policy.targetFrameRate),
                    AVVideoMaxKeyFrameIntervalKey: Int(policy.targetFrameRate * 2),
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
        )
        videoInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(videoInput) else {
            throw VideoCompressionError.writerConfigurationFailed
        }
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if audioOutput != nil, let audioTrack {
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: try await audioWriterSettings(for: audioTrack)
            )
            input.expectsMediaDataInRealTime = false
            guard writer.canAdd(input) else {
                throw VideoCompressionError.audioWriterConfigurationFailed
            }
            writer.add(input)
            audioInput = input
        }

        let job = VideoTranscodeJob(
            reader: reader,
            writer: writer,
            videoOutput: videoOutput,
            videoInput: videoInput,
            audioOutput: audioOutput,
            audioInput: audioInput,
            startTime: timeRange.start,
            duration: max(0.001, CMTimeGetSeconds(timeRange.duration)),
            progress: progress
        )
        try await job.run()
    }

    private func audioWriterSettings(for track: AVAssetTrack) async throws -> [String: Any] {
        let formatDescriptions = try await track.load(.formatDescriptions)
        let sourceDescription = formatDescriptions.first
        let streamDescription = sourceDescription.flatMap {
            CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
        }
        let channelCount = max(1, min(2, Int(streamDescription?.mChannelsPerFrame ?? 2)))
        let sourceSampleRate = streamDescription?.mSampleRate ?? 44_100
        let sampleRate = sourceSampleRate >= 32_000 && sourceSampleRate <= 48_000
            ? sourceSampleRate
            : 44_100

        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVEncoderBitRateKey: policy.targetAudioBitRate
        ]
    }

    private func makeVideoComposition(
        videoTrack: AVAssetTrack,
        assetDuration: CMTime,
        renderPlan: VideoRenderPlan
    ) -> AVMutableVideoComposition {
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(renderPlan.transform, at: .zero)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: assetDuration)
        instruction.layerInstructions = [layerInstruction]

        let composition = AVMutableVideoComposition()
        composition.frameDuration = CMTime(value: 1, timescale: policy.targetFrameRate)
        composition.renderSize = renderPlan.renderSize
        composition.instructions = [instruction]
        return composition
    }

    private func renderPlan(for track: AVAssetTrack) async throws -> VideoRenderPlan {
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let sourceRect = CGRect(origin: .zero, size: naturalSize)
            .applying(preferredTransform)
            .standardized
        guard sourceRect.width > 0, sourceRect.height > 0 else {
            throw VideoCompressionError.invalidVideoDimensions
        }

        let maximumSize = sourceRect.width >= sourceRect.height
            ? targetLandscapeSize
            : CGSize(width: targetLandscapeSize.height, height: targetLandscapeSize.width)
        let scale = min(
            1,
            min(maximumSize.width / sourceRect.width, maximumSize.height / sourceRect.height)
        )
        let renderSize = CGSize(
            width: evenDimension(sourceRect.width * scale),
            height: evenDimension(sourceRect.height * scale)
        )
        let normalizedTransform = preferredTransform.concatenating(
            CGAffineTransform(translationX: -sourceRect.minX, y: -sourceRect.minY)
        )
        let scaledTransform = normalizedTransform.concatenating(
            CGAffineTransform(
                scaleX: renderSize.width / sourceRect.width,
                y: renderSize.height / sourceRect.height
            )
        )

        return VideoRenderPlan(renderSize: renderSize, transform: scaledTransform)
    }

    private func evenDimension(_ value: CGFloat) -> CGFloat {
        max(2, floor(value / 2) * 2)
    }

    private func finalize(drafts: [OptimizedVideoDraft], in directory: URL) throws -> [OptimizedVideoPart] {
        var parts: [OptimizedVideoPart] = []

        do {
            for (index, draft) in drafts.enumerated() {
                let endTime = draft.startTime + draft.duration
                let filename = String(
                    format: "codex-video-%02d_%@-%@.mp4",
                    index + 1,
                    safeTimestamp(draft.startTime),
                    safeTimestamp(endTime)
                )
                let finalURL = directory.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: finalURL.path) {
                    try FileManager.default.removeItem(at: finalURL)
                }
                try FileManager.default.moveItem(at: draft.url, to: finalURL)
                parts.append(
                    OptimizedVideoPart(
                        index: index,
                        url: finalURL,
                        startTime: draft.startTime,
                        duration: draft.duration,
                        fileSize: draft.fileSize
                    )
                )
            }
            return parts
        } catch {
            for draft in drafts where FileManager.default.fileExists(atPath: draft.url.path) {
                try? FileManager.default.removeItem(at: draft.url)
            }
            for part in parts {
                try? FileManager.default.removeItem(at: part.url)
            }
            throw error
        }
    }

    private func safeTimestamp(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remainingSeconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02dh%02dm%02ds", hours, minutes, remainingSeconds)
        }
        return String(format: "%02dm%02ds", minutes, remainingSeconds)
    }

    private func install(stagedParts: [OptimizedVideoPart], in directory: URL) throws -> [OptimizedVideoPart] {
        let fileManager = FileManager.default
        let generationID = String(UUID().uuidString.prefix(8)).lowercased()
        var installedParts: [OptimizedVideoPart] = []

        do {
            for part in stagedParts {
                let stagedName = part.url.lastPathComponent
                let installedName = stagedName.replacingOccurrences(
                    of: "codex-video-",
                    with: "codex-video-\(generationID)-"
                )
                let installedURL = directory.appendingPathComponent(installedName)
                try fileManager.moveItem(at: part.url, to: installedURL)
                installedParts.append(
                    OptimizedVideoPart(
                        index: part.index,
                        url: installedURL,
                        startTime: part.startTime,
                        duration: part.duration,
                        fileSize: part.fileSize
                    )
                )
            }
        } catch {
            for part in installedParts {
                try? fileManager.removeItem(at: part.url)
            }
            throw error
        }

        return installedParts
    }

    private func duration(for asset: AVAsset) async -> TimeInterval {
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

private enum VideoCompressionError: LocalizedError {
    case exportFailed(String)
    case invalidDuration
    case missingVideoTrack
    case invalidVideoDimensions
    case readerConfigurationFailed
    case audioReaderConfigurationFailed
    case writerConfigurationFailed
    case audioWriterConfigurationFailed
    case emptyOutput
    case couldNotMeetFileSizeLimit(Int64)

    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            "Video compression failed: \(message)"
        case .invalidDuration:
            "The video duration could not be read."
        case .missingVideoTrack:
            "The selected file does not contain a video track."
        case .invalidVideoDimensions:
            "The video dimensions could not be read."
        case .readerConfigurationFailed:
            "The video reader could not be configured."
        case .audioReaderConfigurationFailed:
            "The video's audio track could not be read for compression."
        case .writerConfigurationFailed:
            "The 540p video encoder could not be configured."
        case .audioWriterConfigurationFailed:
            "The video's audio track could not be preserved in the compressed file."
        case .emptyOutput:
            "The optimized video file was empty."
        case .couldNotMeetFileSizeLimit(let fileSize):
            "The optimized video could not be kept below 280 MB (\(fileSize) bytes)."
        }
    }
}

private struct VideoRenderPlan {
    var renderSize: CGSize
    var transform: CGAffineTransform
}

private struct OptimizedVideoDraft {
    var url: URL
    var startTime: TimeInterval
    var duration: TimeInterval
    var fileSize: Int64
}

private final class VideoTranscodeJob: @unchecked Sendable {
    private let reader: AVAssetReader
    private let writer: AVAssetWriter
    private let videoOutput: AVAssetReaderOutput
    private let videoInput: AVAssetWriterInput
    private let audioOutput: AVAssetReaderOutput?
    private let audioInput: AVAssetWriterInput?
    private let startTime: CMTime
    private let duration: TimeInterval
    private let progress: @Sendable (Double) -> Void
    private let stateLock = NSLock()
    private var isCancelled = false
    private let queue = DispatchQueue(label: "ReviewTrace.VideoTranscode", qos: .userInitiated)

    init(
        reader: AVAssetReader,
        writer: AVAssetWriter,
        videoOutput: AVAssetReaderOutput,
        videoInput: AVAssetWriterInput,
        audioOutput: AVAssetReaderOutput?,
        audioInput: AVAssetWriterInput?,
        startTime: CMTime,
        duration: TimeInterval,
        progress: @escaping @Sendable (Double) -> Void
    ) {
        self.reader = reader
        self.writer = writer
        self.videoOutput = videoOutput
        self.videoInput = videoInput
        self.audioOutput = audioOutput
        self.audioInput = audioInput
        self.startTime = startTime
        self.duration = duration
        self.progress = progress
    }

    func run() async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !cancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard writer.startWriting() else {
                    continuation.resume(
                        throwing: cancelled
                            ? CancellationError()
                            : VideoCompressionError.exportFailed(writer.error?.localizedDescription ?? "Could not start the writer.")
                    )
                    return
                }
                writer.startSession(atSourceTime: startTime)
                guard reader.startReading() else {
                    writer.cancelWriting()
                    continuation.resume(
                        throwing: cancelled
                            ? CancellationError()
                            : VideoCompressionError.exportFailed(reader.error?.localizedDescription ?? "Could not start the reader.")
                    )
                    return
                }

                queue.async { [self] in
                    do {
                        try pumpSamples()
                        writer.finishWriting { [self] in
                            if writer.status == .completed {
                                progress(1)
                                continuation.resume()
                            } else if cancelled {
                                continuation.resume(throwing: CancellationError())
                            } else {
                                continuation.resume(throwing: VideoCompressionError.exportFailed(writer.error?.localizedDescription ?? "Could not finish the writer."))
                            }
                        }
                    } catch {
                        reader.cancelReading()
                        writer.cancelWriting()
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancel()
        }
    }

    private func pumpSamples() throws {
        var videoFinished = false
        var audioFinished = audioInput == nil || audioOutput == nil
        var lastReportedProgress = -1.0

        while !videoFinished || !audioFinished {
            if cancelled {
                throw CancellationError()
            }
            if writer.status == .failed || writer.status == .cancelled {
                if cancelled {
                    throw CancellationError()
                }
                throw VideoCompressionError.exportFailed(writer.error?.localizedDescription ?? "The writer stopped unexpectedly.")
            }
            if reader.status == .failed || reader.status == .cancelled {
                if cancelled {
                    throw CancellationError()
                }
                throw VideoCompressionError.exportFailed(reader.error?.localizedDescription ?? "The reader stopped unexpectedly.")
            }

            var appendedSample = false

            if !videoFinished, videoInput.isReadyForMoreMediaData {
                if let sampleBuffer = videoOutput.copyNextSampleBuffer() {
                    guard videoInput.append(sampleBuffer) else {
                        throw VideoCompressionError.exportFailed(writer.error?.localizedDescription ?? "A video frame could not be encoded.")
                    }
                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let elapsed = CMTimeGetSeconds(CMTimeSubtract(presentationTime, startTime))
                    let currentProgress = min(max(elapsed / duration, 0), 1)
                    if currentProgress - lastReportedProgress >= 0.01 {
                        lastReportedProgress = currentProgress
                        progress(currentProgress)
                    }
                } else {
                    videoInput.markAsFinished()
                    videoFinished = true
                }
                appendedSample = true
            }

            if !audioFinished,
               let audioInput,
               let audioOutput,
               audioInput.isReadyForMoreMediaData {
                if let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                    guard audioInput.append(sampleBuffer) else {
                        throw VideoCompressionError.exportFailed(writer.error?.localizedDescription ?? "An audio sample could not be encoded.")
                    }
                } else {
                    audioInput.markAsFinished()
                    audioFinished = true
                }
                appendedSample = true
            }

            if !appendedSample {
                Thread.sleep(forTimeInterval: 0.001)
            }
        }

        if reader.status == .failed {
            throw VideoCompressionError.exportFailed(reader.error?.localizedDescription ?? "The reader failed.")
        }
    }

    private var cancelled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isCancelled
    }

    private func cancel() {
        stateLock.lock()
        isCancelled = true
        stateLock.unlock()
        reader.cancelReading()
        writer.cancelWriting()
    }
}

struct JSONExportService {
    func write(session: ReviewSession, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("review-data.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = ReviewExportPayload(session: session)
        let data = try encoder.encode(payload)
        try data.write(to: url, options: [.atomic])
        return url
    }

    func writeTranscript(session: ReviewSession, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("transcript.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(session.transcriptSegments)
        try data.write(to: url, options: [.atomic])
        return url
    }
}

private struct ReviewExportPayload: Codable {
    struct TimelineItem: Codable {
        var startTime: TimeInterval
        var endTime: TimeInterval
        var text: String
        var rawText: String?
        var confidence: Double?
    }

    struct OptimizedVideoItem: Codable {
        var filename: String
        var startTime: TimeInterval
        var duration: TimeInterval
        var fileSize: Int64
    }

    var exportFormatVersion: Int
    var sessionId: String
    var sourceKind: String
    var createdAt: Date
    var duration: TimeInterval
    var videoFilename: String?
    var optimizedVideoFilename: String?
    var optimizedVideos: [OptimizedVideoItem]
    var audioFilename: String?
    var chatGPTReviewFilename: String?
    var timeline: [TimelineItem]
    var readableTimeline: [TimelineItem]
    var codexPrompt: String
    var codexBriefPrompt: String
    var processingSnapshot: ReviewProcessingSnapshot?

    init(session: ReviewSession) {
        self.exportFormatVersion = 7
        self.sessionId = session.id.uuidString
        self.sourceKind = session.resolvedSourceKind.rawValue
        self.createdAt = session.createdAt
        self.duration = session.duration
        self.videoFilename = session.videoURL?.lastPathComponent
        self.optimizedVideoFilename = session.optimizedVideoURL?.lastPathComponent
        self.optimizedVideos = session.resolvedOptimizedVideoParts.map {
            OptimizedVideoItem(
                filename: $0.url.lastPathComponent,
                startTime: $0.startTime,
                duration: $0.duration,
                fileSize: $0.fileSize
            )
        }
        self.audioFilename = session.micAudioURL?.lastPathComponent
        self.chatGPTReviewFilename = session.chatGPTReviewURL?.lastPathComponent
        self.timeline = session.transcriptSegments.map {
            TimelineItem(
                startTime: $0.startTime,
                endTime: $0.endTime,
                text: $0.text,
                rawText: $0.rawText,
                confidence: $0.confidence
            )
        }
        self.readableTimeline = ReadableTimelineBuilder().build(from: session.transcriptSegments).map {
            TimelineItem(
                startTime: $0.startTime,
                endTime: $0.endTime,
                text: $0.text,
                rawText: $0.rawText,
                confidence: $0.confidence
            )
        }
        self.codexPrompt = CodexPromptService().generate(for: session)
        self.codexBriefPrompt = CodexPromptService().generateBrief(for: session)
        self.processingSnapshot = session.processingSnapshot
    }
}

struct SubtitleExportService {
    func writeSRT(session: ReviewSession, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("subtitles.srt")
        try makeSRT(for: session).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func writeVTT(session: ReviewSession, to directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("subtitles.vtt")
        try makeVTT(for: session).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeSRT(for session: ReviewSession) -> String {
        session.transcriptSegments.enumerated().map { index, segment in
            """
            \(index + 1)
            \(ReviewTimeFormatter.srtTimestamp(segment.startTime)) --> \(ReviewTimeFormatter.srtTimestamp(segment.endTime))
            \(segment.text)
            """
        }.joined(separator: "\n\n")
    }

    private func makeVTT(for session: ReviewSession) -> String {
        let cues = session.transcriptSegments.map { segment in
            """
            \(ReviewTimeFormatter.vttTimestamp(segment.startTime)) --> \(ReviewTimeFormatter.vttTimestamp(segment.endTime))
            \(segment.text)
            """
        }.joined(separator: "\n\n")

        return "WEBVTT\n\n\(cues)\n"
    }
}
