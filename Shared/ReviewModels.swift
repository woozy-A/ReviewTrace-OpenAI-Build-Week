import Foundation

struct ReviewSession: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var sourceKind: ReviewSourceKind?
    var transcriptionLanguage: AppLanguage?
    var createdAt: Date
    var broadcastStartedAt: Date?
    var effectiveReviewStartedAt: Date?
    var duration: TimeInterval
    var warmUpDelay: TimeInterval
    var videoURL: URL?
    var optimizedVideoURL: URL?
    var optimizedVideoParts: [OptimizedVideoPart]?
    var micAudioURL: URL?
    var appAudioURL: URL?
    var transcriptSegments: [TranscriptSegment]
    var issueCandidates: [ReviewIssue]
    var markdownURL: URL?
    var readableTimelineURL: URL?
    var originalTimelineURL: URL?
    var jsonURL: URL?
    var codexBriefURL: URL?
    var chatGPTReviewURL: URL?
    var srtURL: URL?
    var vttURL: URL?
    var codexPrompt: String
    var status: ReviewSessionStatus
    var processingSnapshot: ReviewProcessingSnapshot?

    init(
        id: UUID = UUID(),
        title: String,
        sourceKind: ReviewSourceKind = .screenRecording,
        transcriptionLanguage: AppLanguage = .korean,
        createdAt: Date = Date(),
        broadcastStartedAt: Date? = nil,
        effectiveReviewStartedAt: Date? = nil,
        duration: TimeInterval = 0,
        warmUpDelay: TimeInterval = AppConfiguration.defaultWarmUpDelay,
        videoURL: URL? = nil,
        optimizedVideoURL: URL? = nil,
        optimizedVideoParts: [OptimizedVideoPart]? = nil,
        micAudioURL: URL? = nil,
        appAudioURL: URL? = nil,
        transcriptSegments: [TranscriptSegment] = [],
        issueCandidates: [ReviewIssue] = [],
        markdownURL: URL? = nil,
        readableTimelineURL: URL? = nil,
        originalTimelineURL: URL? = nil,
        jsonURL: URL? = nil,
        codexBriefURL: URL? = nil,
        chatGPTReviewURL: URL? = nil,
        srtURL: URL? = nil,
        vttURL: URL? = nil,
        codexPrompt: String = "",
        status: ReviewSessionStatus = .pendingProcessing,
        processingSnapshot: ReviewProcessingSnapshot? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceKind = sourceKind
        self.transcriptionLanguage = transcriptionLanguage
        self.createdAt = createdAt
        self.broadcastStartedAt = broadcastStartedAt
        self.effectiveReviewStartedAt = effectiveReviewStartedAt
        self.duration = duration
        self.warmUpDelay = warmUpDelay
        self.videoURL = videoURL
        self.optimizedVideoURL = optimizedVideoURL
        self.optimizedVideoParts = optimizedVideoParts
        self.micAudioURL = micAudioURL
        self.appAudioURL = appAudioURL
        self.transcriptSegments = transcriptSegments
        self.issueCandidates = issueCandidates
        self.markdownURL = markdownURL
        self.readableTimelineURL = readableTimelineURL
        self.originalTimelineURL = originalTimelineURL
        self.jsonURL = jsonURL
        self.codexBriefURL = codexBriefURL
        self.chatGPTReviewURL = chatGPTReviewURL
        self.srtURL = srtURL
        self.vttURL = vttURL
        self.codexPrompt = codexPrompt
        self.status = status
        self.processingSnapshot = processingSnapshot
    }

    var resolvedSourceKind: ReviewSourceKind {
        sourceKind ?? .screenRecording
    }

    var resolvedTranscriptionLanguage: AppLanguage {
        transcriptionLanguage ?? .korean
    }

    var transcriptionLocaleIdentifier: String {
        resolvedTranscriptionLanguage.rawValue
    }

    var primaryMediaURL: URL? {
        switch resolvedSourceKind {
        case .screenRecording:
            return videoURL ?? micAudioURL
        case .audioFile:
            return micAudioURL ?? videoURL
        }
    }

    var codexPackageMediaURL: URL? {
        codexPackageMediaURLs.first
    }

    var resolvedOptimizedVideoParts: [OptimizedVideoPart] {
        if let optimizedVideoParts, !optimizedVideoParts.isEmpty {
            return optimizedVideoParts.sorted { $0.index < $1.index }
        }
        if let optimizedVideoURL {
            return [
                OptimizedVideoPart(
                    index: 0,
                    url: optimizedVideoURL,
                    startTime: 0,
                    duration: duration,
                    fileSize: 0
                )
            ]
        }
        return []
    }

    var hasCurrentOptimizedVideoParts: Bool {
        let parts = resolvedOptimizedVideoParts
        return !parts.isEmpty && parts.allSatisfy {
            $0.url.lastPathComponent.hasPrefix("codex-video-")
                && FileManager.default.fileExists(atPath: $0.url.path)
        }
    }

    var codexPackageMediaURLs: [URL] {
        switch resolvedSourceKind {
        case .screenRecording:
            let optimizedURLs = resolvedOptimizedVideoParts.map(\.url)
            return optimizedURLs.isEmpty ? [videoURL].compactMap { $0 } : optimizedURLs
        case .audioFile:
            return [micAudioURL ?? videoURL].compactMap { $0 }
        }
    }
}

struct OptimizedVideoPart: Identifiable, Codable, Hashable {
    var id: Int { index }
    var index: Int
    var url: URL
    var startTime: TimeInterval
    var duration: TimeInterval
    var fileSize: Int64
}

enum VideoCompressionStage: String, Hashable {
    case preparing
    case compressing
    case installing
    case completed
    case failed
    case cancelled
}

struct VideoCompressionSnapshot: Hashable {
    var sessionID: UUID
    var stage: VideoCompressionStage
    var progress: Double
    var currentPartIndex: Int?
    var plannedPartCount: Int
    var completedPartCount: Int
    var producedPartCount: Int
    var lastError: String?

    init(
        sessionID: UUID,
        stage: VideoCompressionStage = .preparing,
        progress: Double = 0,
        currentPartIndex: Int? = nil,
        plannedPartCount: Int = 0,
        completedPartCount: Int = 0,
        producedPartCount: Int = 0,
        lastError: String? = nil
    ) {
        self.sessionID = sessionID
        self.stage = stage
        self.progress = min(max(progress, 0), 1)
        self.currentPartIndex = currentPartIndex
        self.plannedPartCount = plannedPartCount
        self.completedPartCount = completedPartCount
        self.producedPartCount = producedPartCount
        self.lastError = lastError
    }

    var isActive: Bool {
        stage == .preparing || stage == .compressing || stage == .installing
    }

    var currentPartDisplayIndex: Int? {
        currentPartIndex.map { $0 + 1 }
    }
}

enum ReviewSourceKind: String, Codable, Hashable {
    case screenRecording
    case audioFile
}

enum ReviewSessionStatus: String, Codable, CaseIterable, Hashable {
    case recording
    case pendingProcessing
    case processing
    case ready
    case failed

    var displayName: String {
        switch self {
        case .recording: "Recording"
        case .pendingProcessing: "Pending"
        case .processing: "Processing"
        case .ready: "Ready"
        case .failed: "Failed"
        }
    }

    func displayName(language: AppLanguage) -> String {
        AppLocalization.string(displayName, language: language)
    }
}

struct TranscriptSegment: Identifiable, Codable, Hashable {
    var id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var rawText: String?
    var confidence: Double?
    var isIssueCandidate: Bool

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        rawText: String? = nil,
        confidence: Double? = nil,
        isIssueCandidate: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.rawText = rawText
        self.confidence = confidence
        self.isIssueCandidate = isIssueCandidate
    }
}

enum AudioChunkStatus: String, Codable, CaseIterable, Hashable {
    case pending
    case processing
    case completed
    case failed
}

struct AudioChunk: Identifiable, Codable, Hashable {
    var id: UUID
    var url: URL
    var index: Int
    var startOffset: TimeInterval
    var duration: TimeInterval
    var status: AudioChunkStatus
    var transcriptSegments: [TranscriptSegment]

    init(
        id: UUID = UUID(),
        url: URL,
        index: Int,
        startOffset: TimeInterval,
        duration: TimeInterval,
        status: AudioChunkStatus = .pending,
        transcriptSegments: [TranscriptSegment] = []
    ) {
        self.id = id
        self.url = url
        self.index = index
        self.startOffset = startOffset
        self.duration = duration
        self.status = status
        self.transcriptSegments = transcriptSegments
    }
}

enum ReviewProcessingStage: String, Codable, Hashable {
    case importingVideo
    case importingAudio
    case extractingAudio
    case chunkingAudio
    case transcribingChunks
    case mergingTranscript
    case creatingExports
    case completed
    case failed
}

struct ReviewProcessingSnapshot: Codable, Hashable {
    var sessionID: UUID
    var stage: ReviewProcessingStage
    var sourceKind: ReviewSourceKind?
    var transcriptionLanguage: AppLanguage?
    var videoDuration: TimeInterval
    var extractedAudioDuration: TimeInterval?
    var extractedAudioFileSize: Int64?
    var audioTrackCount: Int
    var chunkCount: Int
    var currentChunkIndex: Int?
    var completedChunkCount: Int
    var failedChunkIndex: Int?
    var transcriptionBackend: String
    var rawSegmentCount: Int
    var groupedTimelineRowCount: Int
    var lastError: String?
    var extractedAudioURL: URL?
    var chunkURLs: [URL]
    var startedAt: Date
    var updatedAt: Date

    init(
        sessionID: UUID,
        stage: ReviewProcessingStage,
        sourceKind: ReviewSourceKind = .screenRecording,
        transcriptionLanguage: AppLanguage = .korean,
        videoDuration: TimeInterval = 0,
        extractedAudioDuration: TimeInterval? = nil,
        extractedAudioFileSize: Int64? = nil,
        audioTrackCount: Int = 0,
        chunkCount: Int = 0,
        currentChunkIndex: Int? = nil,
        completedChunkCount: Int = 0,
        failedChunkIndex: Int? = nil,
        transcriptionBackend: String = "Apple Speech",
        rawSegmentCount: Int = 0,
        groupedTimelineRowCount: Int = 0,
        lastError: String? = nil,
        extractedAudioURL: URL? = nil,
        chunkURLs: [URL] = [],
        startedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.sessionID = sessionID
        self.stage = stage
        self.sourceKind = sourceKind
        self.transcriptionLanguage = transcriptionLanguage
        self.videoDuration = videoDuration
        self.extractedAudioDuration = extractedAudioDuration
        self.extractedAudioFileSize = extractedAudioFileSize
        self.audioTrackCount = audioTrackCount
        self.chunkCount = chunkCount
        self.currentChunkIndex = currentChunkIndex
        self.completedChunkCount = completedChunkCount
        self.failedChunkIndex = failedChunkIndex
        self.transcriptionBackend = transcriptionBackend
        self.rawSegmentCount = rawSegmentCount
        self.groupedTimelineRowCount = groupedTimelineRowCount
        self.lastError = lastError
        self.extractedAudioURL = extractedAudioURL
        self.chunkURLs = chunkURLs
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }

    var resolvedTranscriptionLanguage: AppLanguage {
        transcriptionLanguage ?? .korean
    }

    var progress: Double {
        switch stage {
        case .importingVideo, .importingAudio:
            return 0.05
        case .extractingAudio:
            return 0.12
        case .chunkingAudio:
            return 0.18
        case .transcribingChunks:
            guard chunkCount > 0 else { return 0.2 }
            return min(0.9, 0.2 + (Double(completedChunkCount) / Double(chunkCount)) * 0.68)
        case .mergingTranscript:
            return 0.92
        case .creatingExports:
            return 0.96
        case .completed:
            return 1
        case .failed:
            return max(0.05, min(0.95, chunkCount > 0 ? 0.2 + (Double(completedChunkCount) / Double(chunkCount)) * 0.68 : 0.2))
        }
    }

    var currentChunkDisplayIndex: Int? {
        currentChunkIndex.map { $0 + 1 }
    }

    var failedChunkDisplayIndex: Int? {
        failedChunkIndex.map { $0 + 1 }
    }
}

struct ReviewIssue: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var category: IssueCategory
    var severity: Severity
    var timestamp: TimeInterval
    var evidenceText: String
    var suggestedFix: String?

    init(
        id: UUID = UUID(),
        title: String,
        category: IssueCategory,
        severity: Severity,
        timestamp: TimeInterval,
        evidenceText: String,
        suggestedFix: String? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.severity = severity
        self.timestamp = timestamp
        self.evidenceText = evidenceText
        self.suggestedFix = suggestedFix
    }
}

enum IssueCategory: String, Codable, CaseIterable, Hashable {
    case ux
    case ui
    case bug
    case navigation
    case copywriting
    case accessibility
    case performance
    case onboarding
    case unknown

    var displayName: String {
        switch self {
        case .ux: "UX"
        case .ui: "UI"
        case .bug: "Bug"
        case .navigation: "Navigation"
        case .copywriting: "Copywriting"
        case .accessibility: "Accessibility"
        case .performance: "Performance"
        case .onboarding: "Onboarding"
        case .unknown: "Unknown"
        }
    }

    func displayName(language: AppLanguage) -> String {
        AppLocalization.string(displayName, language: language)
    }
}

enum Severity: String, Codable, CaseIterable, Hashable, Comparable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    func displayName(language: AppLanguage) -> String {
        AppLocalization.string(displayName, language: language)
    }

    private var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }
}

struct BroadcastSessionMetadata: Identifiable, Codable, Hashable {
    var id: UUID { sessionId }
    var sessionId: UUID
    var title: String?
    var sourceKind: ReviewSourceKind?
    var createdAt: Date
    var broadcastStartedAt: Date?
    var effectiveReviewStartedAt: Date?
    var warmUpDelay: TimeInterval
    var firstVideoPresentationTimestamp: Double?
    var firstMicPresentationTimestamp: Double?
    var videoRelativePath: String?
    var micAudioRelativePath: String?
    var appAudioRelativePath: String?
    var status: ReviewSessionStatus
    var errorMessage: String?
}
