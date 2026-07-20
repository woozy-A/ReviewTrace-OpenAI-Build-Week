import Foundation
import Observation

@MainActor
@Observable
final class ReviewTraceStore {
    var appLanguage: AppLanguage = AppConfiguration.defaultAppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: Self.appLanguageDefaultsKey)
        }
    }
    var transcriptionLanguage: AppLanguage = .korean {
        didSet {
            UserDefaults.standard.set(transcriptionLanguage.rawValue, forKey: Self.transcriptionLanguageDefaultsKey)
        }
    }
    var sessions: [ReviewSession] = []
    var isProcessing = false
    var processingTitle = "리뷰 처리 중"
    var processingProgress = 0.0
    var processingSnapshot: ReviewProcessingSnapshot?
    var videoCompressionSnapshot: VideoCompressionSnapshot?
    var errorMessage: String?

    private let metadataStore: BroadcastSessionMetadataStore
    private let persistence: ReviewSessionPersistence
    private let pipeline: ReviewProcessingPipeline
    @ObservationIgnored private let videoCompressionService = VideoCompressionService()
    @ObservationIgnored private var processingOperationTask: Task<Void, Never>?
    @ObservationIgnored private var videoCompressionTask: Task<[OptimizedVideoPart], Error>?
    private let titleGenerator = ReviewTitleGenerator()
    private var deletedSessionIDs: Set<UUID> = []
    private var activeProcessingSessionID: UUID?
    private static let appLanguageDefaultsKey = "ReviewTrace.appLanguage"
    private static let transcriptionLanguageDefaultsKey = "ReviewTrace.transcriptionLanguage"

    init(
        metadataStore: BroadcastSessionMetadataStore = BroadcastSessionMetadataStore(),
        persistence: ReviewSessionPersistence = ReviewSessionPersistence(),
        pipeline: ReviewProcessingPipeline = ReviewProcessingPipeline()
    ) {
        self.metadataStore = metadataStore
        self.persistence = persistence
        self.pipeline = pipeline
        if let storedValue = UserDefaults.standard.string(forKey: Self.appLanguageDefaultsKey),
           let storedLanguage = AppLanguage(rawValue: storedValue) {
            self.appLanguage = storedLanguage
        }
        if let storedValue = UserDefaults.standard.string(forKey: Self.transcriptionLanguageDefaultsKey),
           let storedLanguage = AppLanguage(rawValue: storedValue) {
            self.transcriptionLanguage = storedLanguage
        }
        loadSessions()
    }

    var copy: AppCopy {
        AppCopy(language: appLanguage)
    }

    var isBackgroundWorkActive: Bool {
        processingOperationTask != nil || videoCompressionTask != nil
    }

    func loadSessions() {
        do {
            sessions = try persistence.load()
            repairMissingChatGPTExports()
        } catch {
            sessions = []
            errorMessage = error.localizedDescription
        }
    }

    func importExistingRecordingData(_ data: Data) async {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        do {
            try data.write(to: temporaryURL, options: [.atomic])
            await importExistingRecordingFile(at: temporaryURL, ownsSourceFile: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importExistingRecordingFile(at sourceURL: URL, ownsSourceFile: Bool = false) async {
        await importMediaFile(
            at: sourceURL,
            sourceKind: .screenRecording,
            defaultTitle: copy.importedReviewTitle,
            importingTitle: copy.importingRecording,
            destinationBaseName: "recording",
            fallbackExtension: "mov",
            ownsSourceFile: ownsSourceFile
        )
    }

    func importAudioFile(at sourceURL: URL) async {
        await importMediaFile(
            at: sourceURL,
            sourceKind: .audioFile,
            defaultTitle: copy.importedAudioReviewTitle,
            importingTitle: copy.importingAudioFile,
            destinationBaseName: "audioReview",
            fallbackExtension: "m4a",
            ownsSourceFile: false
        )
    }

    private func importMediaFile(
        at sourceURL: URL,
        sourceKind: ReviewSourceKind,
        defaultTitle: String,
        importingTitle: String,
        destinationBaseName: String,
        fallbackExtension: String,
        ownsSourceFile: Bool
    ) async {
        guard !isBackgroundWorkActive else {
            if ownsSourceFile {
                try? FileManager.default.removeItem(at: sourceURL)
            }
            errorMessage = copy.anotherTaskInProgress
            return
        }

        // STUDY: Capture the choice now so later settings changes cannot alter this review mid-processing.
        let selectedTranscriptionLanguage = transcriptionLanguage
        let operation = Task { @MainActor in
            await performImportMediaFile(
                at: sourceURL,
                sourceKind: sourceKind,
                defaultTitle: defaultTitle,
                importingTitle: importingTitle,
                destinationBaseName: destinationBaseName,
                fallbackExtension: fallbackExtension,
                ownsSourceFile: ownsSourceFile,
                transcriptionLanguage: selectedTranscriptionLanguage
            )
        }
        processingOperationTask = operation
        await operation.value
        processingOperationTask = nil
    }

    private func performImportMediaFile(
        at sourceURL: URL,
        sourceKind: ReviewSourceKind,
        defaultTitle: String,
        importingTitle: String,
        destinationBaseName: String,
        fallbackExtension: String,
        ownsSourceFile: Bool,
        transcriptionLanguage: AppLanguage
    ) async {
        isProcessing = true
        if videoCompressionSnapshot?.isActive != true {
            videoCompressionSnapshot = nil
        }
        processingTitle = importingTitle
        processingProgress = 0.1
        processingSnapshot = nil
        var createdDirectory: URL?

        defer {
            if ownsSourceFile, FileManager.default.fileExists(atPath: sourceURL.path) {
                try? FileManager.default.removeItem(at: sourceURL)
            }
            activeProcessingSessionID = nil
            processingProgress = processingSnapshot?.progress ?? 1.0
            isProcessing = false
        }

        do {
            try Task.checkCancellation()
            let metadata = try metadataStore.createSession(title: defaultTitle, warmUpDelay: 0)
            let directory = try metadataStore.sessionDirectory(for: metadata.sessionId)
            createdDirectory = directory
            activeProcessingSessionID = metadata.sessionId
            let pathExtension = sourceURL.pathExtension.isEmpty ? fallbackExtension : sourceURL.pathExtension
            let mediaURL = directory.appendingPathComponent(destinationBaseName).appendingPathExtension(pathExtension)
            try await installSourceFile(from: sourceURL, to: mediaURL, moveSource: ownsSourceFile)
            try Task.checkCancellation()

            try metadataStore.update(metadata.sessionId) { updated in
                updated.sourceKind = sourceKind
                switch sourceKind {
                case .screenRecording:
                    updated.videoRelativePath = try? metadataStore.relativePath(for: mediaURL)
                case .audioFile:
                    updated.videoRelativePath = nil
                    updated.micAudioRelativePath = try? metadataStore.relativePath(for: mediaURL)
                    updated.appAudioRelativePath = nil
                }
                updated.status = .processing
            }

            processingProgress = 0.35
            let session = ReviewSession(
                id: metadata.sessionId,
                title: defaultTitle,
                sourceKind: sourceKind,
                transcriptionLanguage: transcriptionLanguage,
                createdAt: metadata.createdAt,
                broadcastStartedAt: nil,
                effectiveReviewStartedAt: nil,
                warmUpDelay: 0,
                videoURL: sourceKind == .screenRecording ? mediaURL : nil,
                micAudioURL: sourceKind == .audioFile ? mediaURL : nil,
                status: .processing
            )

            let processed = await pipeline.process(session, outputDirectory: directory, language: appLanguage) { snapshot in
                await MainActor.run {
                    self.processingSnapshot = snapshot
                    self.processingProgress = snapshot.progress
                    self.processingTitle = self.copy.processingTitle(for: snapshot)
                }
            }
            guard !Task.isCancelled, !deletedSessionIDs.contains(session.id) else {
                if FileManager.default.fileExists(atPath: directory.path) {
                    try? FileManager.default.removeItem(at: directory)
                }
                processingSnapshot = nil
                processingProgress = 0
                return
            }
            var finalSession = processed
            applyGeneratedTitleIfNeeded(to: &finalSession)
            refreshChatGPTExport(for: &finalSession, in: directory)

            processingProgress = 0.9
            try metadataStore.updateStatus(sessionId: metadata.sessionId, status: finalSession.status)
            try? metadataStore.update(metadata.sessionId) { updated in
                updated.title = finalSession.title
            }
            merge([finalSession])
            saveSessions()
            processingSnapshot = finalSession.processingSnapshot
            createdDirectory = nil
        } catch {
            if !(error is CancellationError),
               activeProcessingSessionID.map({ !deletedSessionIDs.contains($0) }) ?? true {
                errorMessage = error.localizedDescription
            }
            if let createdDirectory,
               FileManager.default.fileExists(atPath: createdDirectory.path) {
                try? FileManager.default.removeItem(at: createdDirectory)
            }
        }
    }

    func retryLastFailedProcessing() async {
        guard let sessionID = processingSnapshot?.sessionID ?? sessions.first(where: { $0.status == .failed })?.id else {
            return
        }
        await retryProcessing(sessionID: sessionID)
    }

    func dismissProcessingFailure() {
        guard processingSnapshot?.stage == .failed else { return }
        processingSnapshot = nil
        processingProgress = 0
        processingTitle = copy.processingTitle
        isProcessing = false
    }

    func updateSessionTitle(id: UUID, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              let index = sessions.firstIndex(where: { $0.id == id }) else {
            return
        }

        sessions[index].title = trimmedTitle
        let directory = sessionDirectoryURL(for: sessions[index])
        refreshChatGPTExport(for: &sessions[index], in: directory)
        saveSessions()

        do {
            try metadataStore.update(id) { metadata in
                metadata.title = trimmedTitle
            }
        } catch {
            // Metadata may not exist for older imported samples; the library title is still saved.
        }
    }

    @discardableResult
    func prepareOptimizedVideoForCodexPackage(sessionID: UUID) async -> Bool {
        guard !isBackgroundWorkActive else {
            errorMessage = copy.anotherTaskInProgress
            return false
        }
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            errorMessage = copy.reviewNotFoundDescription
            return false
        }
        guard sessions[index].resolvedSourceKind == .screenRecording else {
            return true
        }
        guard let directory = sessionDirectoryURL(for: sessions[index]) else {
            errorMessage = copy.reviewNotFoundDescription
            return false
        }

        let sourceSession = sessions[index]
        var installedParts: [OptimizedVideoPart] = []
        var didCommitInstalledParts = false
        videoCompressionSnapshot = VideoCompressionSnapshot(
            sessionID: sessionID,
            stage: .preparing,
            progress: 0.01
        )
        let service = videoCompressionService
        let task = Task {
            try await service.writeCodexPreviewsIfNeeded(
                session: sourceSession,
                to: directory,
                force: true,
                progress: { snapshot in
                    Task { @MainActor [weak self] in
                        self?.receiveVideoCompressionSnapshot(snapshot)
                    }
                }
            )
        }
        videoCompressionTask = task
        defer { videoCompressionTask = nil }

        do {
            let optimizedParts = try await task.value
            installedParts = optimizedParts
            guard !Task.isCancelled,
                  !deletedSessionIDs.contains(sessionID),
                  let currentIndex = sessions.firstIndex(where: { $0.id == sessionID }) else {
                for part in optimizedParts {
                    try? FileManager.default.removeItem(at: part.url)
                }
                return false
            }

            var updatedSession = sessions[currentIndex]
            updatedSession.optimizedVideoParts = optimizedParts
            updatedSession.optimizedVideoURL = optimizedParts.first?.url
            try refreshPackageExports(for: &updatedSession, in: directory)
            let previousSession = sessions[currentIndex]
            sessions[currentIndex] = updatedSession
            do {
                try persistence.save(sessions)
            } catch {
                sessions[currentIndex] = previousSession
                var restoredSession = previousSession
                try? refreshPackageExports(for: &restoredSession, in: directory)
                throw error
            }
            didCommitInstalledParts = true
            let installedURLs = Set(optimizedParts.map(\.url))
            removeStaleOptimizedVideoFiles(in: directory, keeping: installedURLs)
            receiveVideoCompressionSnapshot(
                VideoCompressionSnapshot(
                    sessionID: sessionID,
                    stage: .completed,
                    progress: 1,
                    plannedPartCount: videoCompressionSnapshot?.plannedPartCount ?? optimizedParts.count,
                    completedPartCount: videoCompressionSnapshot?.completedPartCount ?? optimizedParts.count,
                    producedPartCount: optimizedParts.count
                )
            )
            return true
        } catch is CancellationError {
            if !didCommitInstalledParts {
                for part in installedParts {
                    try? FileManager.default.removeItem(at: part.url)
                }
            }
            receiveVideoCompressionSnapshot(
                terminalCompressionSnapshot(sessionID: sessionID, stage: .cancelled)
            )
            return false
        } catch {
            if !didCommitInstalledParts {
                for part in installedParts {
                    try? FileManager.default.removeItem(at: part.url)
                }
            }
            receiveVideoCompressionSnapshot(
                terminalCompressionSnapshot(
                    sessionID: sessionID,
                    stage: .failed,
                    error: error.localizedDescription
                )
            )
            return false
        }
    }

    func requiresOptimizedVideoForCodexPackage(sessionID: UUID) -> Bool {
        guard let session = session(with: sessionID),
              session.resolvedSourceKind == .screenRecording,
              !session.hasCurrentOptimizedVideoParts,
              let videoURL = session.videoURL else {
            return false
        }
        return VideoCompressionPolicy.codex.requiresCompression(fileSize: fileSize(at: videoURL))
    }

    func cancelVideoCompression(sessionID: UUID) {
        guard videoCompressionSnapshot?.sessionID == sessionID,
              videoCompressionSnapshot?.isActive == true else {
            return
        }
        videoCompressionTask?.cancel()
        receiveVideoCompressionSnapshot(
            terminalCompressionSnapshot(sessionID: sessionID, stage: .cancelled)
        )
    }

    @discardableResult
    func retryVideoCompression(sessionID: UUID) async -> Bool {
        await prepareOptimizedVideoForCodexPackage(sessionID: sessionID)
    }

    func dismissVideoCompressionStatus() {
        guard videoCompressionSnapshot?.isActive != true else { return }
        videoCompressionSnapshot = nil
    }

    func retryProcessing(sessionID: UUID) async {
        guard !isBackgroundWorkActive else {
            errorMessage = copy.anotherTaskInProgress
            return
        }
        let operation = Task { @MainActor in
            await performRetryProcessing(sessionID: sessionID)
        }
        processingOperationTask = operation
        await operation.value
        processingOperationTask = nil
    }

    private func performRetryProcessing(sessionID: UUID) async {
        guard var session = session(with: sessionID),
              let directory = sessionDirectoryURL(for: session) else {
            errorMessage = copy.reviewNotFoundDescription
            return
        }

        isProcessing = true
        if videoCompressionSnapshot?.isActive != true {
            videoCompressionSnapshot = nil
        }
        session.status = .processing
        processingSnapshot = session.processingSnapshot
        processingTitle = copy.processingTitle
        processingProgress = processingSnapshot?.progress ?? 0.1
        activeProcessingSessionID = sessionID
        merge([session])
        saveSessions()
        defer {
            activeProcessingSessionID = nil
            isProcessing = false
        }

        let processed = await pipeline.process(session, outputDirectory: directory, language: appLanguage) { snapshot in
            await MainActor.run {
                self.processingSnapshot = snapshot
                self.processingProgress = snapshot.progress
                self.processingTitle = self.copy.processingTitle(for: snapshot)
            }
        }
        guard !Task.isCancelled, !deletedSessionIDs.contains(sessionID) else {
            processingSnapshot = nil
            processingProgress = 0
            return
        }

        do {
            try metadataStore.updateStatus(sessionId: sessionID, status: processed.status)
        } catch {
            errorMessage = error.localizedDescription
        }
        var finalSession = processed
        applyGeneratedTitleIfNeeded(to: &finalSession)
        refreshChatGPTExport(for: &finalSession, in: directory)
        try? metadataStore.update(sessionID) { metadata in
            metadata.title = finalSession.title
        }
        merge([finalSession])
        saveSessions()
        processingSnapshot = finalSession.processingSnapshot
        processingProgress = finalSession.processingSnapshot?.progress ?? processingProgress
    }

    @discardableResult
    func deleteAllData() -> Bool {
        do {
            deletedSessionIDs.formUnion(sessions.map(\.id))
            if let activeProcessingSessionID {
                deletedSessionIDs.insert(activeProcessingSessionID)
            }
            if let compressionSessionID = videoCompressionSnapshot?.sessionID {
                deletedSessionIDs.insert(compressionSessionID)
            }
            processingOperationTask?.cancel()
            videoCompressionTask?.cancel()
            sessions.removeAll()
            processingSnapshot = nil
            videoCompressionSnapshot = nil
            processingProgress = 0
            isProcessing = false
            try persistence.deleteLibrary()
            let sessionsRoot = try metadataStore.sessionsRootURL()
            if FileManager.default.fileExists(atPath: sessionsRoot.path) {
                try FileManager.default.removeItem(at: sessionsRoot)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func deleteSession(id: UUID) -> Bool {
        do {
            guard let session = session(with: id) else { return false }
            deletedSessionIDs.insert(id)
            if activeProcessingSessionID == id {
                processingOperationTask?.cancel()
            }
            if videoCompressionSnapshot?.sessionID == id {
                videoCompressionTask?.cancel()
                videoCompressionSnapshot = nil
            }
            if let directory = sessionDirectoryURL(for: session),
               FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            sessions.removeAll { $0.id == id }
            try persistence.save(sessions)
            if processingSnapshot?.sessionID == id {
                processingSnapshot = nil
                processingProgress = 0
                isProcessing = false
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func session(with id: UUID) -> ReviewSession? {
        sessions.first { $0.id == id }
    }

    private func installSourceFile(from sourceURL: URL, to destinationURL: URL, moveSource: Bool) async throws {
        try Task.checkCancellation()
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            if moveSource {
                do {
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                    return
                } catch {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                    try? fileManager.removeItem(at: sourceURL)
                    return
                }
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }.value
        try Task.checkCancellation()
    }

    private func refreshPackageExports(for session: inout ReviewSession, in directory: URL) throws {
        let markdownService = MarkdownExportService()
        session.codexPrompt = CodexPromptService().generate(for: session, language: appLanguage)
        session.codexBriefURL = try markdownService.writeCodexBrief(
            session: session,
            to: directory,
            language: appLanguage
        )
        session.chatGPTReviewURL = try markdownService.writeChatGPTReview(
            session: session,
            to: directory,
            language: appLanguage
        )
        session.markdownURL = try markdownService.write(
            session: session,
            to: directory,
            language: appLanguage
        )
        session.jsonURL = try JSONExportService().write(session: session, to: directory)
    }

    private func removeStaleOptimizedVideoFiles(in directory: URL, keeping URLs: Set<URL>) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        for url in contents where !URLs.contains(url) {
            let name = url.lastPathComponent
            if name.hasPrefix("codex-video-") || name.hasPrefix("codex-preview.") {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func receiveVideoCompressionSnapshot(_ snapshot: VideoCompressionSnapshot) {
        guard !deletedSessionIDs.contains(snapshot.sessionID) else { return }

        if let current = videoCompressionSnapshot, current.sessionID == snapshot.sessionID {
            if !current.isActive, snapshot.isActive {
                return
            }
            if current.stage == .cancelled {
                return
            }
            if current.stage == .failed, snapshot.stage != .failed {
                return
            }
            if current.isActive, snapshot.isActive, snapshot.progress < current.progress {
                var monotonicSnapshot = snapshot
                monotonicSnapshot.progress = current.progress
                videoCompressionSnapshot = monotonicSnapshot
                return
            }
        }
        videoCompressionSnapshot = snapshot
    }

    private func terminalCompressionSnapshot(
        sessionID: UUID,
        stage: VideoCompressionStage,
        error: String? = nil
    ) -> VideoCompressionSnapshot {
        let current = videoCompressionSnapshot?.sessionID == sessionID ? videoCompressionSnapshot : nil
        return VideoCompressionSnapshot(
            sessionID: sessionID,
            stage: stage,
            progress: current?.progress ?? 0,
            currentPartIndex: current?.currentPartIndex,
            plannedPartCount: current?.plannedPartCount ?? 0,
            completedPartCount: current?.completedPartCount ?? 0,
            producedPartCount: current?.producedPartCount ?? 0,
            lastError: error
        )
    }

    private func fileSize(at url: URL) -> Int64 {
        let value = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? NSNumber
        return value?.int64Value ?? 0
    }

    private func applyGeneratedTitleIfNeeded(to session: inout ReviewSession) {
        guard shouldGenerateTitle(for: session.title) else { return }
        let fallback = session.resolvedSourceKind == .audioFile ? copy.importedAudioReviewTitle : copy.importedReviewTitle
        let baseTitle = titleGenerator.generateTitle(for: session, fallback: fallback)
        session.title = uniqueGeneratedTitle(baseTitle, excluding: session.id)
    }

    private func shouldGenerateTitle(for title: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitles = [
            AppCopy(language: .korean).importedReviewTitle,
            AppCopy(language: .english).importedReviewTitle,
            AppCopy(language: .korean).importedAudioReviewTitle,
            AppCopy(language: .english).importedAudioReviewTitle
        ]
        return trimmedTitle.isEmpty || defaultTitles.contains(trimmedTitle)
    }

    private func uniqueGeneratedTitle(_ baseTitle: String, excluding sessionID: UUID) -> String {
        let existingTitles = Set(
            sessions
                .filter { $0.id != sessionID }
                .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        guard existingTitles.contains(baseTitle) else { return baseTitle }

        var index = 2
        while existingTitles.contains("\(baseTitle) \(index)") {
            index += 1
        }
        return "\(baseTitle) \(index)"
    }

    private func merge(_ newSessions: [ReviewSession]) {
        for session in newSessions {
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            } else {
                sessions.insert(session, at: 0)
            }
        }
        sessions.sort { $0.createdAt > $1.createdAt }
    }

    private func saveSessions() {
        do {
            try persistence.save(sessions)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func repairMissingChatGPTExports() {
        var didChange = false

        for index in sessions.indices {
            let existingURL = sessions[index].chatGPTReviewURL
            if let existingURL, FileManager.default.fileExists(atPath: existingURL.path) {
                continue
            }
            guard sessions[index].status == .ready,
                  !sessions[index].transcriptSegments.isEmpty,
                  let directory = sessionDirectoryURL(for: sessions[index]) else {
                continue
            }

            if let url = try? MarkdownExportService().writeChatGPTReview(
                session: sessions[index],
                to: directory,
                language: appLanguage
            ) {
                sessions[index].chatGPTReviewURL = url
                didChange = true
            }
        }

        if didChange {
            try? persistence.save(sessions)
        }
    }

    private func refreshChatGPTExport(for session: inout ReviewSession, in directory: URL?) {
        guard session.status == .ready,
              !session.transcriptSegments.isEmpty,
              let directory,
              let url = try? MarkdownExportService().writeChatGPTReview(
                session: session,
                to: directory,
                language: appLanguage
              ) else {
            return
        }
        session.chatGPTReviewURL = url
    }

    private func sessionDirectoryURL(for session: ReviewSession) -> URL? {
        let topLevelURLs = session.resolvedOptimizedVideoParts.map(\.url) + [
            session.videoURL,
            session.optimizedVideoURL,
            session.micAudioURL,
            session.appAudioURL,
            session.markdownURL,
            session.readableTimelineURL,
            session.originalTimelineURL,
            session.jsonURL,
            session.codexBriefURL,
            session.chatGPTReviewURL,
            session.srtURL,
            session.vttURL
        ].compactMap { $0 }

        if let url = topLevelURLs.first {
            return url.deletingLastPathComponent()
        }

        if let chunkURL = session.processingSnapshot?.chunkURLs.first {
            return chunkURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        }

        return nil
    }
}

private struct ReviewTitleGenerator {
    private let ignoredTokens: Set<String> = [
        "앱", "리뷰", "영상", "녹화", "화면", "전사", "타임라인", "문서", "패키지",
        "이거", "그거", "저거", "여기", "저기", "일단", "근데", "그리고", "그래서",
        "하는데", "하려고", "처음부터", "다시", "배우기", "버튼", "기능", "문제",
        "부분", "사용", "사람", "정도", "확인", "텍스트", "있는", "없는", "같아",
        "같고", "너무", "되게", "좋겠어", "하면", "해서", "이제", "랑", "하고",
        "codex", "reviewtrace", "screen", "recording", "review", "video", "app", "the",
        "and", "with", "this", "that", "button", "screen", "timeline", "transcript"
    ]

    func generateTitle(for session: ReviewSession, fallback: String) -> String {
        let candidate = bestCandidate(from: session.transcriptSegments)
        let englishFallbacks = [
            AppCopy(language: .english).importedReviewTitle,
            AppCopy(language: .english).importedAudioReviewTitle
        ]
        let suffix = englishFallbacks.contains(fallback) ? " Review" : " 리뷰"

        if let candidate {
            return "\(candidate)\(suffix)"
        }

        let duration = ReviewTimeFormatter.clock(session.duration)
        return fallback == AppCopy(language: .english).importedReviewTitle
            ? "\(fallback) \(duration)"
            : "\(fallback) \(duration)"
    }

    private func bestCandidate(from segments: [TranscriptSegment]) -> String? {
        let text = segments
            .prefix(40)
            .map(\.text)
            .joined(separator: " ")
        let tokens = extractTokens(from: text)
        guard !tokens.isEmpty else { return nil }

        var counts: [String: Int] = [:]
        var displayValues: [String: String] = [:]
        var firstIndexes: [String: Int] = [:]

        for (index, token) in tokens.enumerated() {
            guard let normalized = normalizedToken(token) else { continue }
            counts[normalized, default: 0] += 1
            displayValues[normalized] = displayValues[normalized] ?? token
            firstIndexes[normalized] = firstIndexes[normalized] ?? index
        }

        return counts
            .map { key, count in
                let display = displayValues[key] ?? key
                let firstIndex = firstIndexes[key] ?? 0
                let score = score(token: display, count: count, firstIndex: firstIndex)
                return (display: display, score: score)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.display.count > rhs.display.count
                }
                return lhs.score > rhs.score
            }
            .first?
            .display
    }

    private func extractTokens(from text: String) -> [String] {
        let pattern = #"[\p{L}\p{N}]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private func normalizedToken(_ token: String) -> String? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }
        guard !trimmed.allSatisfy({ $0.isNumber }) else { return nil }

        let normalized = trimmed.lowercased()
        guard !ignoredTokens.contains(normalized) else { return nil }
        return normalized
    }

    private func score(token: String, count: Int, firstIndex: Int) -> Double {
        var score = Double(count * 10)
        score += Double(min(token.count, 12))
        score -= Double(firstIndex) * 0.06

        if token.contains(where: { $0.isUppercase }) {
            score += 4
        }
        if token.range(of: #"^[A-Z0-9]{2,}$"#, options: .regularExpression) != nil {
            score += 3
        }
        return score
    }
}

struct AppCopy {
    let language: AppLanguage

    var homeTab: String { language == .korean ? "홈" : "Home" }
    var reviewsTab: String { language == .korean ? "리뷰" : "Reviews" }
    var settingsTab: String { language == .korean ? "설정" : "Settings" }

    var checkingPendingBroadcasts: String { language == .korean ? "대기 중인 방송 확인" : "Checking pending broadcasts" }
    var importingRecording: String { language == .korean ? "녹화 파일 가져오는 중" : "Importing recording" }
    var importingAudioFile: String { language == .korean ? "음성 파일 가져오는 중" : "Importing audio file" }
    var importedReviewTitle: String { language == .korean ? "화면 녹화 리뷰" : "Screen Recording Review" }
    var importedAudioReviewTitle: String { language == .korean ? "음성 리뷰" : "Audio Review" }

    var homeHeroTitle: String { language == .korean ? "앱 리뷰 영상을\nCodex 작업 문서로" : "Turn app review videos\ninto Codex work documents" }
    var homeHeroSubtitle: String {
        language == .korean
            ? "말하면서 남긴 피드백을 영상 타임라인에 맞춰 전사합니다."
            : "Transcribe spoken feedback against the video timeline."
    }
    var startReview: String { language == .korean ? "화면 녹화 가져오기" : "Import Screen Recording" }
    var importing: String { language == .korean ? "가져오는 중..." : "Importing..." }
    var importExistingRecording: String { language == .korean ? "화면 녹화 가져오기" : "Import Screen Recording" }
    var importAudioFile: String { language == .korean ? "음성 파일 가져오기" : "Import Audio File" }
    var importAudioFileDescription: String {
        language == .korean
            ? "개발 회의 녹음이나 음성 메모를 타임라인 전사로 바꿉니다."
            : "Turn development meeting recordings or voice notes into a timeline transcript."
    }
    var spokenReviewLanguage: String {
        language == .korean ? "이번 리뷰에서 말한 언어" : "Language Spoken in This Review"
    }
    var spokenReviewLanguageHelp: String {
        language == .korean
            ? "가져올 영상이나 음성에서 실제로 말한 언어를 선택하세요. 앱 표시 언어와는 별개입니다."
            : "Choose the language actually spoken in the video or audio. This is separate from the app language."
    }
    func transcriptionLanguageName(_ transcriptionLanguage: AppLanguage, includesLocale: Bool = false) -> String {
        let name: String
        switch transcriptionLanguage {
        case .korean:
            name = language == .korean ? "한국어" : "Korean"
        case .english:
            name = "English"
        }
        return includesLocale ? "\(name) (\(transcriptionLanguage.rawValue))" : name
    }
    var recentReviews: String { language == .korean ? "최근 리뷰" : "Recent Reviews" }
    func recentReviewsLimit(_ count: Int) -> String {
        language == .korean ? "최근 리뷰 \(count)개" : "\(count) Recent Reviews"
    }
    func recentReviewsDescription(_ count: Int) -> String {
        language == .korean
            ? "최신순 최대 \(count)개만 홈에 보여줍니다."
            : "Home shows the latest \(count) reviews."
    }
    var noReviewsTitle: String { language == .korean ? "아직 리뷰가 없어요" : "No Reviews Yet" }
    var noReviewsDescription: String {
        language == .korean
            ? "마이크를 켠 화면 녹화 영상이나 개발 회의 음성 파일을 가져오세요."
            : "Import a screen recording with microphone audio or a development meeting audio file."
    }

    func sourceLabel(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return language == .korean ? "영상" : "Video"
        case .audioFile:
            return language == .korean ? "음성" : "Audio"
        }
    }

    func transcriptCount(_ count: Int) -> String {
        language == .korean ? "전사 \(count)개" : "\(count) transcript segments"
    }

    func displayTitle(_ title: String) -> String {
        guard language == .korean else { return title }
        switch title {
        case "Screen Recording Review":
            return importedReviewTitle
        default:
            return title
        }
    }

    var howToRecord: String { language == .korean ? "녹화 방법 안내" : "How to record" }
    var quickRecordStep1: String { language == .korean ? "마이크 켜고 화면 녹화" : "Record with microphone on" }
    var quickRecordStep2: String { language == .korean ? "앱을 사용하며 말로 리뷰" : "Use the app while speaking feedback" }
    var quickRecordStep3: String { language == .korean ? "녹화 종료 후 가져오기" : "Import after recording" }
    var recordStep1: String { language == .korean ? "제어 센터 열기" : "Open Control Center" }
    var recordStep2: String { language == .korean ? "화면 기록 시작" : "Start Screen Recording" }
    var recordStep3: String { language == .korean ? "마이크 오디오 켜기" : "Turn Microphone On" }
    var recordStep4: String { language == .korean ? "앱을 사용하며 말로 피드백 남기기" : "Test your app while speaking feedback" }
    var recordStep5: String { language == .korean ? "녹화 종료 후 이 앱에서 가져오기" : "Import the video here after recording" }

    var importVideoTitle: String { language == .korean ? "화면 녹화 선택" : "Select Screen Recording" }
    var importVideoSubtitle: String {
        language == .korean
            ? "마이크를 켠 상태로 녹화한 영상을 선택하세요. 영상 시간이 타임라인 기준이 됩니다."
            : "Choose a screen recording with microphone audio. The video timeline becomes the review timeline."
    }
    var selectVideo: String { language == .korean ? "비디오 선택하기" : "Select Video" }
    var importPrivacyCopy: String {
        language == .korean
            ? "ReviewTrace는 가져온 화면 녹화를 로컬에서 처리합니다. 민감한 정보가 포함된 영상은 신중하게 가져오세요."
            : "ReviewTrace processes imported screen recordings locally. Only import recordings you intend to review."
    }

    var startReviewTitle: String { importVideoTitle }
    var openControlCenter: String { language == .korean ? "제어 센터 열기" : "Open Control Center" }
    var longPressScreenRecording: String { language == .korean ? "화면 녹화 길게 누르기" : "Long press Screen Recording" }
    var selectReviewTrace: String { language == .korean ? "ReviewTrace 선택" : "Select ReviewTrace" }
    var turnMicrophoneOn: String { recordStep3 }
    var tapStartBroadcast: String { language == .korean ? "방송 시작" : "Tap Start Broadcast" }
    var warmUpDelay: String { language == .korean ? "웜업 시간 설정" : "Warm-up Delay" }
    func seconds(_ value: TimeInterval) -> String {
        language == .korean ? "\(Int(value))초" : "\(Int(value)) seconds"
    }
    var reviewLanguage: String { language == .korean ? "언어 설정" : "Review Language" }
    var whenRecordingStarts: String { language == .korean ? "녹화가 시작되면" : "When recording starts" }
    func warmUpInstruction(_ delay: TimeInterval) -> String {
        language == .korean
            ? "녹화가 시작되면 \(Int(delay))초 뒤부터 리뷰 타임라인이 시작됩니다. 그 후 테스트할 앱으로 이동해서 말하면서 사용하세요."
            : "When recording starts, the review timeline begins after \(Int(delay)) seconds. Then switch to the app you want to test and speak naturally."
    }
    var openBroadcastPicker: String { language == .korean ? "방송 선택기 열기" : "Open Broadcast Picker" }
    var sensitiveRecordingWarning: String {
        language == .korean
            ? "화면 녹화에는 민감한 정보가 포함될 수 있어요. 녹화 시작과 중지는 항상 iOS 시스템 화면에서 직접 확인하세요."
            : "Screen recordings may include sensitive information. Start and stop recording only through the visible iOS system controls."
    }

    var processingTitle: String { language == .korean ? "처리 중..." : "Processing..." }
    var recordingFound: String { language == .korean ? "영상 가져오기 완료" : "Video imported" }
    var audioFound: String { language == .korean ? "오디오 읽는 중" : "Reading audio" }
    func transcribingSpeech(_ transcriptionLanguage: AppLanguage) -> String {
        let spokenLanguage = transcriptionLanguageName(transcriptionLanguage)
        return language == .korean
            ? "음성 인식 중 (\(spokenLanguage))"
            : "Transcribing \(spokenLanguage) speech..."
    }
    var buildingTimeline: String { language == .korean ? "타임라인 생성" : "Building timeline" }
    var creatingCodexPrompt: String { language == .korean ? "내보내기 파일 생성" : "Creating exports" }
    var progress: String { language == .korean ? "진행률" : "Progress" }
    var retryFailedChunk: String { language == .korean ? "실패 구간 재시도" : "Retry Failed Chunk" }
    var close: String { language == .korean ? "닫기" : "Close" }
    var closeAndSelectAgain: String { language == .korean ? "닫고 다른 파일 선택" : "Close and Choose Another File" }
    var failureReason: String { language == .korean ? "실패 이유" : "Failure reason" }
    var processingFailed: String { language == .korean ? "처리 실패" : "Processing Failed" }
    var errorTitle: String { language == .korean ? "오류" : "Error" }
    var anotherTaskInProgress: String {
        language == .korean
            ? "다른 가져오기 또는 영상 준비 작업이 진행 중입니다. 완료하거나 취소한 뒤 다시 시도해 주세요."
            : "Another import or video preparation task is running. Finish or cancel it before trying again."
    }
    var processingCompletedDescription: String {
        language == .korean
            ? "전사와 Codex 작업 패키지가 준비되었습니다. 리뷰 상세 화면에서 추천 패키지를 공유하세요."
            : "The transcript and Codex work package are ready. Share the recommended package from the review detail screen."
    }
    var processingFailedDescription: String {
        language == .korean
            ? "완료된 구간은 보존됩니다. 실패 구간만 다시 시도하거나 닫고 다른 영상을 선택할 수 있습니다."
            : "Completed chunks are preserved. Retry the failed chunk or close this and choose another video."
    }
    var extractedAudio: String { language == .korean ? "추출된 오디오" : "Extracted audio" }
    var failedChunk: String { language == .korean ? "실패한 구간" : "Failed chunk" }
    var videoLength: String { language == .korean ? "영상 길이" : "Video length" }
    func sourceLength(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return videoLength
        case .audioFile:
            return language == .korean ? "음성 길이" : "Audio length"
        }
    }
    var totalChunks: String { language == .korean ? "총 구간" : "Total chunks" }
    var completedChunks: String { language == .korean ? "완료 구간" : "Completed chunks" }
    var currentChunk: String { language == .korean ? "현재 구간" : "Current chunk" }
    var rawSegments: String { language == .korean ? "원본 전사 조각" : "Raw segments" }
    var timelineRows: String { language == .korean ? "타임라인 행" : "Timeline rows" }

    func chunkProgress(_ snapshot: ReviewProcessingSnapshot) -> String {
        let completedPercent = Int(snapshot.progress * 100)
        if let current = snapshot.currentChunkDisplayIndex {
            return language == .korean
                ? "총 \(snapshot.chunkCount)개 구간 중 \(current)번째 전사 중 · 완료 \(completedPercent)%"
                : "Chunk \(current) of \(snapshot.chunkCount) · \(completedPercent)% complete"
        }
        return language == .korean
            ? "총 \(snapshot.chunkCount)개 구간 · 완료 \(snapshot.completedChunkCount)개"
            : "\(snapshot.chunkCount) chunks · \(snapshot.completedChunkCount) complete"
    }

    func processingTitle(for snapshot: ReviewProcessingSnapshot) -> String {
        switch snapshot.stage {
        case .importingVideo:
            return importingRecording
        case .importingAudio:
            return importingAudioFile
        case .extractingAudio:
            return language == .korean ? "영상 오디오 추출 중" : "Extracting audio"
        case .chunkingAudio:
            return language == .korean ? "오디오 구간 나누는 중" : "Splitting audio"
        case .transcribingChunks:
            let spokenLanguage = transcriptionLanguageName(snapshot.resolvedTranscriptionLanguage)
            if snapshot.chunkCount > 0, let current = snapshot.currentChunkDisplayIndex {
                return language == .korean
                    ? "총 \(snapshot.chunkCount)개 구간 중 \(current)번째 \(spokenLanguage) 전사 중"
                    : "Transcribing \(spokenLanguage) chunk \(current) of \(snapshot.chunkCount)"
            }
            return transcribingSpeech(snapshot.resolvedTranscriptionLanguage)
        case .mergingTranscript:
            return buildingTimeline
        case .creatingExports:
            return creatingCodexPrompt
        case .completed:
            return language == .korean ? "전사 패키지 준비 완료" : "Transcript package ready"
        case .failed:
            return processingFailed
        }
    }

    func lengthWarning(for duration: TimeInterval) -> String? {
        if duration > 3600 {
            return language == .korean
                ? "1시간이 넘는 리뷰입니다. 정확도와 처리 속도를 위해 여러 파일로 나누는 것을 권장합니다."
                : "This review is longer than 1 hour. Splitting it into multiple files is recommended for accuracy and speed."
        }
        if duration > 1800 {
            return language == .korean
                ? "긴 리뷰 모드입니다. 처리 중 앱을 열어두는 것을 권장합니다."
                : "Long review mode. Keeping the app open during processing is recommended."
        }
        if duration > 600 {
            return language == .korean
                ? "긴 리뷰입니다. 처리 시간이 조금 걸릴 수 있습니다."
                : "This is a long review. Processing may take a while."
        }
        return nil
    }

    var reviewNotFound: String { language == .korean ? "리뷰를 찾을 수 없어요" : "Review Not Found" }
    var reviewNotFoundDescription: String {
        language == .korean
            ? "선택한 리뷰가 삭제되었을 수 있어요."
            : "The selected review may have been deleted."
    }
    var reviewNavigationTitle: String { language == .korean ? "리뷰" : "Review" }
    var timeline: String { language == .korean ? "타임라인" : "Timeline" }
    var readableTimeline: String { language == .korean ? "읽기용" : "Readable" }
    var originalTimeline: String { language == .korean ? "원문" : "Original" }
    var readableTimelineDescription: String {
        language == .korean
            ? "짧은 전사 행을 자연스럽게 묶고, 점 하나 같은 잡음은 제외한 보기입니다."
            : "Short rows are grouped for readability, and punctuation-only noise is hidden."
    }
    var originalTimelineDescription: String {
        language == .korean
            ? "전사 결과를 시간순으로 최대한 보존한 보기입니다. 자막/검증에는 이 기준이 더 가깝습니다."
            : "Keeps transcript rows closer to the original timing. This is better for subtitles and verification."
    }
    var export: String { language == .korean ? "내보내기" : "Export" }
    var codex: String { "Codex" }
    var videoUnavailable: String {
        language == .korean
            ? "영상 미리보기를 불러오지 못했습니다. 전사 결과는 계속 사용할 수 있습니다."
            : "Video preview could not be loaded. The transcript is still available."
    }
    var videoPreview: String { language == .korean ? "영상 미리보기" : "Video Preview" }
    var audioPreview: String { language == .korean ? "음성 파일" : "Audio File" }
    var audioUnavailable: String {
        language == .korean
            ? "음성 파일을 불러오지 못했습니다. 전사 결과는 계속 사용할 수 있습니다."
            : "Audio file could not be loaded. The transcript is still available."
    }
    var recommendedExport: String { language == .korean ? "추천" : "Recommended" }
    var otherExportFormats: String { language == .korean ? "다른 형식" : "Other Formats" }
    var shareOptionsTitle: String { language == .korean ? "직접 리뷰 전달" : "Direct Review Handoff" }
    var shareOptionsSummary: String {
        language == .korean
            ? "화면 녹화 또는 음성, 타임스탬프 정렬 전사, 직접 구현 지시문을 하나의 패키지로 전달합니다."
            : "Share the recording or audio, timestamp-aligned transcript, and direct implementation instructions as one package."
    }
    var codexPackageTitle: String { language == .korean ? "직접 리뷰 전달" : "Direct Review Handoff" }
    func codexPackageSummary(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return language == .korean
                ? "영상, 타임스탬프 전사, 구현 지시문을 Codex에 전달합니다."
                : "Share the video, timestamped transcript, and implementation instructions with Codex."
        case .audioFile:
            return language == .korean
                ? "음성, 타임스탬프 전사, 구현 지시문을 Codex에 전달합니다."
                : "Share the audio, timestamped transcript, and implementation instructions with Codex."
        }
    }
    var codexPromptTitle: String { language == .korean ? "직접 리뷰 전달" : "Direct Review Handoff" }
    func codexPromptSummary(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return language == .korean
                ? "녹화와 타임라인을 사용해 리뷰어가 명시한 요청을 코드에 직접 구현하도록 안내합니다."
                : "Use the recording and timeline to implement the reviewer's explicit requests directly in code."
        case .audioFile:
            return language == .korean
                ? "음성 녹음과 타임스탬프 정렬 전사를 사용해 리뷰어가 명시한 요청을 코드에 직접 구현하도록 안내합니다."
                : "Use the audio recording and timestamp-aligned transcript to implement the reviewer's explicit requests directly in code."
        }
    }
    var includedContents: String { language == .korean ? "포함 내용" : "Included" }
    var includedVideo: String { language == .korean ? "화면 녹화 또는 최적화 분할 영상" : "Screen recording or optimized video parts" }
    var includedAudio: String { language == .korean ? "음성 녹음" : "Audio recording" }
    var includedTimeline: String { language == .korean ? "타임스탬프 정렬 전사" : "Timestamp-aligned transcript" }
    var includedPrompt: String { language == .korean ? "직접 구현 지시문" : "Direct implementation instructions" }
    var fullPrompt: String { language == .korean ? "리뷰 지시문 전문" : "Full Review Instructions" }
    var noTimeline: String { language == .korean ? "타임라인 없음" : "No Timeline" }
    func jumpToSource(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return language == .korean ? "영상으로 이동" : "Jump to video"
        case .audioFile:
            return language == .korean ? "음성으로 이동" : "Jump to audio"
        }
    }
    var copied: String { language == .korean ? "복사됨" : "Copied" }
    var copyCodexPrompt: String { language == .korean ? "리뷰 지시문 복사" : "Copy Review Instructions" }
    var shareToChatGPT: String { language == .korean ? "ChatGPT에 단일 문서 공유" : "Share Single Document with ChatGPT" }
    var shareVideoAndReview: String { language == .korean ? "Codex로 리뷰 전달" : "Share Review with Codex" }
    func shareMediaOnly(for sourceKind: ReviewSourceKind, partCount: Int) -> String {
        switch sourceKind {
        case .screenRecording:
            if language == .korean {
                return partCount > 1 ? "분할 영상만 공유" : "영상만 공유"
            }
            return partCount > 1 ? "Share Video Parts Only" : "Share Video Only"
        case .audioFile:
            return language == .korean ? "음성만 공유" : "Share Audio Only"
        }
    }
    var makeOptimizedVideo: String { language == .korean ? "Codex용 작은 영상 만들기" : "Make Optimized Codex Video" }
    var makingOptimizedVideo: String { language == .korean ? "작은 영상 만드는 중..." : "Making optimized video..." }
    var optimizedVideoRequired: String {
        language == .korean
            ? "전체 패키지를 공유하려면 먼저 작은 영상을 준비하세요. 전사 결과는 이미 사용할 수 있습니다."
            : "Prepare smaller video files before sharing the full package. The transcript is already available."
    }
    var cancelVideoCompression: String { language == .korean ? "영상 준비 취소" : "Cancel Video Preparation" }
    var retryVideoCompression: String { language == .korean ? "영상 준비 재시도" : "Retry Video Preparation" }
    var videoCompressionFailed: String { language == .korean ? "작은 영상 준비 실패" : "Video Preparation Failed" }
    var videoCompressionCancelled: String { language == .korean ? "영상 준비 취소됨" : "Video Preparation Cancelled" }
    func videoCompressionTitle(_ snapshot: VideoCompressionSnapshot) -> String {
        switch snapshot.stage {
        case .preparing:
            return language == .korean ? "압축 준비 중" : "Preparing Video"
        case .compressing:
            if let current = snapshot.currentPartDisplayIndex, snapshot.plannedPartCount > 0 {
                return language == .korean
                    ? "총 \(snapshot.plannedPartCount)개 구간 중 \(current)번째 압축 중"
                    : "Compressing part \(current) of \(snapshot.plannedPartCount)"
            }
            return makingOptimizedVideo
        case .installing:
            return language == .korean ? "작은 영상 저장 중" : "Saving Optimized Videos"
        case .completed:
            return optimizedVideoReady(partCount: snapshot.producedPartCount)
        case .failed:
            return videoCompressionFailed
        case .cancelled:
            return videoCompressionCancelled
        }
    }
    func videoCompressionDetail(_ snapshot: VideoCompressionSnapshot) -> String? {
        guard snapshot.plannedPartCount > 0 else { return nil }
        return language == .korean
            ? "계획 \(snapshot.plannedPartCount)개 · 완료 \(snapshot.completedPartCount)개 · 생성 \(snapshot.producedPartCount)개"
            : "Planned \(snapshot.plannedPartCount) · completed \(snapshot.completedPartCount) · produced \(snapshot.producedPartCount)"
    }
    func optimizedVideoReady(partCount: Int) -> String {
        if language == .korean {
            return partCount > 1 ? "압축본 \(partCount)개 준비 완료" : "압축본 준비 완료"
        }
        return partCount > 1 ? "\(partCount) optimized videos ready" : "Optimized video ready"
    }
    var optimizedVideoDescription: String {
        language == .korean
            ? "540p·30fps로 줄이고 파일당 280MB를 넘으면 타임스탬프 구간별로 자동 분할합니다. 전사는 원본 오디오를 사용합니다."
            : "Creates 540p, 30 fps copies and splits them by timestamp when a file would exceed 280 MB. Transcription still uses the original audio."
    }
    var exportJSONDescription: String {
        language == .korean
            ? "타임스탬프, 전사, 처리 정보를 담은 자동화/개발자용 데이터"
            : "Developer/automation data with timestamps, transcript rows, and processing metadata."
    }
    var exportReadableTimelineDescription: String {
        language == .korean
            ? "짧은 행을 자연스럽게 묶은 사람이 읽기 좋은 타임라인"
            : "Human-readable timeline with short rows grouped naturally."
    }
    var exportOriginalTimelineDescription: String {
        language == .korean
            ? "자막, 시간 검증, 정확한 근거 확인용 원문 타임라인"
            : "Original transcript timeline for subtitles, timestamp checks, and evidence."
    }
    var exportSRTDescription: String {
        language == .korean
            ? "일반 영상 편집기나 플레이어에 붙이는 표준 자막"
            : "Standard subtitles for video editors and players."
    }
    var exportVTTDescription: String {
        language == .korean
            ? "웹 플레이어와 브라우저 자막에 쓰는 형식"
            : "Subtitle format for web players and browsers."
    }
    var cancel: String { language == .korean ? "취소" : "Cancel" }
    var delete: String { language == .korean ? "삭제" : "Delete" }
    var save: String { language == .korean ? "저장" : "Save" }
    var ok: String { language == .korean ? "확인" : "OK" }
    var editReviewTitle: String { language == .korean ? "리뷰 제목 수정" : "Edit Review Title" }
    var reviewTitle: String { language == .korean ? "리뷰 제목" : "Review Title" }
    var reviewTitleHelp: String {
        language == .korean
            ? "ReviewTrace는 영상만으로 어떤 앱을 리뷰했는지 자동으로 알 수 없어요. 알아보기 쉬운 이름으로 직접 적어주세요."
            : "ReviewTrace cannot reliably detect which app was reviewed from the video alone. Name it so you can recognize it later."
    }
    var deleteReview: String { language == .korean ? "리뷰 삭제" : "Delete Review" }
    var deleteReviewConfirmTitle: String { language == .korean ? "이 리뷰를 삭제할까요?" : "Delete this review?" }
    var deleteReviewConfirmMessage: String {
        language == .korean
            ? "삭제하면 이 리뷰의 원본 파일, 전사, 내보내기 파일을 복구할 수 없습니다."
            : "This will permanently delete the source file, transcript, and export files for this review."
    }
    var deleteCompletedTitle: String { language == .korean ? "삭제 완료" : "Deleted" }
    func deleteReviewCompletedMessage(_ title: String) -> String {
        language == .korean
            ? "\(title) 삭제가 완료되었습니다."
            : "\(title) has been deleted."
    }

    var settingsTitle: String { language == .korean ? "설정" : "Settings" }
    var general: String { language == .korean ? "일반" : "General" }
    var appLanguage: String { language == .korean ? "앱 언어" : "App Language" }
    var defaultTranscriptionLanguage: String { language == .korean ? "기본 전사 언어" : "Default Transcription Language" }
    var exportDefaultFormat: String { language == .korean ? "내보내기 기본 형식" : "Default export format" }
    var privacy: String { language == .korean ? "개인정보" : "Privacy" }
    var localFileStorage: String { language == .korean ? "파일은 앱 내부에 저장" : "Files Stay in the App" }
    var speechRecognitionPrivacy: String { language == .korean ? "Apple 음성 인식" : "Apple Speech Recognition" }
    var privacyExplanation: String {
        language == .korean
            ? "가져온 원본, 전사, 내보내기 파일은 ReviewTrace의 앱 저장 공간에 보관되며 사용자가 공유할 때만 다른 앱으로 전달됩니다."
            : "Imported sources, transcripts, and exports are stored in ReviewTrace and leave the app only when you choose to share them."
    }
    var speechRecognitionPrivacyExplanation: String {
        language == .korean
            ? "음성 인식은 기기, 언어, 네트워크 상태에 따라 Apple 서버를 사용할 수 있습니다. ReviewTrace는 온디바이스 전용 처리를 보장하지 않습니다."
            : "Speech recognition may use Apple servers depending on the device, language, and network. ReviewTrace does not guarantee on-device-only recognition."
    }
    var exportStyle: String { language == .korean ? "내보내기 형식" : "Export Style" }
    var structuredJSON: String { language == .korean ? "구조화 데이터 JSON" : "Structured JSON Data" }
    var subtitleExports: String { language == .korean ? "SRT/VTT 자막" : "SRT/VTT Subtitles" }
    var dataManagement: String { language == .korean ? "데이터 관리" : "Data Management" }
    var deleteAllRecordings: String { language == .korean ? "모든 리뷰 삭제" : "Delete all recordings" }
    var deleteAllConfirmTitle: String { language == .korean ? "모든 리뷰를 삭제할까요?" : "Delete all reviews?" }
    var deleteAllConfirmMessage: String {
        language == .korean
            ? "삭제하면 모든 리뷰 원본 파일과 전사, 내보내기 파일을 복구할 수 없습니다."
            : "This will permanently delete every review source file, transcript, and export file."
    }
    var deleteAllCompletedMessage: String { language == .korean ? "모든 리뷰가 삭제되었습니다." : "All reviews have been deleted." }
}
