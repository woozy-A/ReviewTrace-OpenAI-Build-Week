import Foundation
import Observation

@MainActor
@Observable
final class ReviewTraceStore {
    private(set) var appLanguage: AppLanguage
    private(set) var transcriptionLanguage: AppLanguage
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
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var transcriptionLanguageFollowsAppLanguage: Bool
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
        pipeline: ReviewProcessingPipeline = ReviewProcessingPipeline(),
        userDefaults: UserDefaults = .standard
    ) {
        self.metadataStore = metadataStore
        self.persistence = persistence
        self.pipeline = pipeline
        self.userDefaults = userDefaults

        let storedAppLanguage = userDefaults.string(forKey: Self.appLanguageDefaultsKey)
            .flatMap(AppLanguage.init(rawValue:))
        let resolvedAppLanguage = storedAppLanguage ?? AppConfiguration.defaultAppLanguage
        self.appLanguage = resolvedAppLanguage

        let storedTranscriptionLanguage = userDefaults.string(forKey: Self.transcriptionLanguageDefaultsKey)
            .flatMap(AppLanguage.init(rawValue:))
        self.transcriptionLanguage = storedTranscriptionLanguage ?? resolvedAppLanguage
        self.transcriptionLanguageFollowsAppLanguage = storedTranscriptionLanguage == nil

        if storedTranscriptionLanguage == nil {
            userDefaults.removeObject(forKey: Self.transcriptionLanguageDefaultsKey)
        }
        loadSessions()
    }

    func setAppLanguage(_ language: AppLanguage) {
        guard appLanguage != language else { return }

        appLanguage = language
        userDefaults.set(language.rawValue, forKey: Self.appLanguageDefaultsKey)

        if transcriptionLanguageFollowsAppLanguage {
            transcriptionLanguage = language
        }
    }

    func setTranscriptionLanguage(_ language: AppLanguage) {
        transcriptionLanguageFollowsAppLanguage = false
        transcriptionLanguage = language
        userDefaults.set(language.rawValue, forKey: Self.transcriptionLanguageDefaultsKey)
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

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, language: language)
    }

    private func formatted(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: localized(key),
            locale: language.locale,
            arguments: arguments
        )
    }

    var homeTab: String { localized("Home") }
    var reviewsTab: String { localized("Reviews") }
    var settingsTab: String { localized("Settings") }

    var checkingPendingBroadcasts: String { localized("Checking pending broadcasts") }
    var importingRecording: String { localized("Importing recording") }
    var importingAudioFile: String { localized("Importing audio file") }
    var importedReviewTitle: String { localized("Screen Recording Review") }
    var importedAudioReviewTitle: String { localized("Audio Review") }

    var homeHeroTitle: String { localized("Turn app review videos\ninto Codex work documents") }
    var homeHeroSubtitle: String {
        localized("Transcribe spoken feedback against the video timeline.")
    }
    var startReview: String { localized("Import Screen Recording") }
    var importing: String { localized("Importing...") }
    var importExistingRecording: String { localized("Import Screen Recording") }
    var importAudioFile: String { localized("Import Audio File") }
    var importAudioFileDescription: String {
        localized("Turn development meeting recordings or voice notes into a timeline transcript.")
    }
    var spokenReviewLanguage: String {
        localized("Language Spoken in This Review")
    }
    var spokenReviewLanguageHelp: String {
        localized("Choose the language actually spoken in the video or audio. This is separate from the app language.")
    }
    func transcriptionLanguageName(
        _ transcriptionLanguage: AppLanguage,
        includesLocale: Bool = false
    ) -> String {
        let name: String
        switch transcriptionLanguage {
        case .korean:
            name = localized("Korean")
        case .english:
            name = localized("English")
        }
        return includesLocale
            ? formatted("%1$@ (%2$@)", name, transcriptionLanguage.rawValue)
            : name
    }
    var recentReviews: String { localized("Recent Reviews") }
    func recentReviewsLimit(_ count: Int) -> String {
        formatted("%@ Recent Reviews", String(count))
    }
    func recentReviewsDescription(_ count: Int) -> String {
        formatted("Home shows the latest %@ reviews.", String(count))
    }
    var noReviewsTitle: String { localized("No Reviews Yet") }
    var noReviewsDescription: String {
        localized("Import a screen recording with microphone audio or a development meeting audio file.")
    }

    func sourceLabel(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return localized("Video")
        case .audioFile:
            return localized("Audio")
        }
    }

    func transcriptCount(_ count: Int) -> String {
        formatted("%@ transcript segments", String(count))
    }

    func displayTitle(_ title: String) -> String {
        switch title {
        case "Screen Recording Review":
            return importedReviewTitle
        case "Audio Review":
            return importedAudioReviewTitle
        default:
            return title
        }
    }

    var howToRecord: String { localized("How to record") }
    var quickRecordStep1: String { localized("Record with microphone on") }
    var quickRecordStep2: String { localized("Use the app while speaking feedback") }
    var quickRecordStep3: String { localized("Import after recording") }
    var recordStep1: String { localized("Open Control Center") }
    var recordStep2: String { localized("Start Screen Recording") }
    var recordStep3: String { localized("Turn Microphone On") }
    var recordStep4: String { localized("Test your app while speaking feedback") }
    var recordStep5: String { localized("Import the video here after recording") }

    var importVideoTitle: String { localized("Select Screen Recording") }
    var importVideoSubtitle: String {
        localized("Choose a screen recording with microphone audio. The video timeline becomes the review timeline.")
    }
    var selectVideo: String { localized("Select Video") }
    var importPrivacyCopy: String {
        localized("ReviewTrace processes imported screen recordings locally. Only import recordings you intend to review.")
    }

    var startReviewTitle: String { importVideoTitle }
    var openControlCenter: String { localized("Open Control Center") }
    var longPressScreenRecording: String { localized("Long press Screen Recording") }
    var selectReviewTrace: String { localized("Select ReviewTrace") }
    var turnMicrophoneOn: String { recordStep3 }
    var tapStartBroadcast: String { localized("Tap Start Broadcast") }
    var warmUpDelay: String { localized("Warm-up Delay") }
    func seconds(_ value: TimeInterval) -> String {
        formatted("%@ seconds", String(Int(value)))
    }
    var reviewLanguage: String { localized("Review Language") }
    var whenRecordingStarts: String { localized("When recording starts") }
    func warmUpInstruction(_ delay: TimeInterval) -> String {
        formatted(
            "When recording starts, the review timeline begins after %@ seconds. Then switch to the app you want to test and speak naturally.",
            String(Int(delay))
        )
    }
    var openBroadcastPicker: String { localized("Open Broadcast Picker") }
    var sensitiveRecordingWarning: String {
        localized("Screen recordings may include sensitive information. Start and stop recording only through the visible iOS system controls.")
    }

    var processingTitle: String { localized("Processing...") }
    var recordingFound: String { localized("Video imported") }
    var audioFound: String { localized("Reading audio") }
    func transcribingSpeech(_ transcriptionLanguage: AppLanguage) -> String {
        formatted(
            "Transcribing %@ speech...",
            transcriptionLanguageName(transcriptionLanguage)
        )
    }
    var buildingTimeline: String { localized("Building timeline") }
    var creatingCodexPrompt: String { localized("Creating exports") }
    var progress: String { localized("Progress") }
    var retryFailedChunk: String { localized("Retry Failed Chunk") }
    var close: String { localized("Close") }
    var closeAndSelectAgain: String { localized("Close and Choose Another File") }
    var failureReason: String { localized("Failure reason") }
    var processingFailed: String { localized("Processing Failed") }
    var errorTitle: String { localized("Error") }
    var anotherTaskInProgress: String {
        localized("Another import or video preparation task is running. Finish or cancel it before trying again.")
    }
    var processingCompletedDescription: String {
        localized("The transcript and Codex work package are ready. Share the recommended package from the review detail screen.")
    }
    var processingFailedDescription: String {
        localized("Completed chunks are preserved. Retry the failed chunk or close this and choose another video.")
    }
    var extractedAudio: String { localized("Extracted audio") }
    var failedChunk: String { localized("Failed chunk") }
    var videoLength: String { localized("Video length") }
    func sourceLength(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return videoLength
        case .audioFile:
            return localized("Audio length")
        }
    }
    var totalChunks: String { localized("Total chunks") }
    var completedChunks: String { localized("Completed chunks") }
    var currentChunk: String { localized("Current chunk") }
    var rawSegments: String { localized("Raw segments") }
    var timelineRows: String { localized("Timeline rows") }
    var audioProcessing: String { localized("audio processing") }
    var videoProcessing: String { localized("video processing") }

    func chunkProgress(_ snapshot: ReviewProcessingSnapshot) -> String {
        let completedPercent = Int(snapshot.progress * 100)
        if let current = snapshot.currentChunkDisplayIndex {
            return formatted(
                "Chunk %1$@ of %2$@ · %3$@%% complete",
                String(current),
                String(snapshot.chunkCount),
                String(completedPercent)
            )
        }
        return formatted(
            "%1$@ chunks · %2$@ complete",
            String(snapshot.chunkCount),
            String(snapshot.completedChunkCount)
        )
    }

    func processingTitle(for snapshot: ReviewProcessingSnapshot) -> String {
        switch snapshot.stage {
        case .importingVideo:
            return importingRecording
        case .importingAudio:
            return importingAudioFile
        case .extractingAudio:
            return localized("Extracting audio")
        case .chunkingAudio:
            return localized("Splitting audio")
        case .transcribingChunks:
            let spokenLanguage = transcriptionLanguageName(snapshot.resolvedTranscriptionLanguage)
            if snapshot.chunkCount > 0, let current = snapshot.currentChunkDisplayIndex {
                return formatted(
                    "Transcribing %1$@ chunk %2$@ of %3$@",
                    spokenLanguage,
                    String(current),
                    String(snapshot.chunkCount)
                )
            }
            return transcribingSpeech(snapshot.resolvedTranscriptionLanguage)
        case .mergingTranscript:
            return buildingTimeline
        case .creatingExports:
            return creatingCodexPrompt
        case .completed:
            return localized("Transcript package ready")
        case .failed:
            return processingFailed
        }
    }

    func lengthWarning(for duration: TimeInterval) -> String? {
        if duration > 3600 {
            return localized("This review is longer than 1 hour. Splitting it into multiple files is recommended for accuracy and speed.")
        }
        if duration > 1800 {
            return localized("Long review mode. Keeping the app open during processing is recommended.")
        }
        if duration > 600 {
            return localized("This is a long review. Processing may take a while.")
        }
        return nil
    }

    var reviewNotFound: String { localized("Review Not Found") }
    var reviewNotFoundDescription: String {
        localized("The selected review may have been deleted.")
    }
    var reviewNavigationTitle: String { localized("Review") }
    var timeline: String { localized("Timeline") }
    var readableTimeline: String { localized("Readable") }
    var originalTimeline: String { localized("Original") }
    var readableTimelineDescription: String {
        localized("Short rows are grouped for readability, and punctuation-only noise is hidden.")
    }
    var originalTimelineDescription: String {
        localized("Keeps transcript rows closer to the original timing. This is better for subtitles and verification.")
    }
    var export: String { localized("Export") }
    var codex: String { localized("Codex") }
    var videoUnavailable: String {
        localized("Video preview could not be loaded. The transcript is still available.")
    }
    var videoPreview: String { localized("Video Preview") }
    var audioPreview: String { localized("Audio File") }
    var audioUnavailable: String {
        localized("Audio file could not be loaded. The transcript is still available.")
    }
    var recommendedExport: String { localized("Recommended") }
    var otherExportFormats: String { localized("Other Formats") }
    var shareOptionsTitle: String { localized("Direct Review Handoff") }
    var shareOptionsSummary: String {
        localized("Share the recording or audio, timestamp-aligned transcript, and direct implementation instructions as one package.")
    }
    var codexPackageTitle: String { localized("Direct Review Handoff") }
    func codexPackageSummary(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return localized("Share the video, timestamped transcript, and implementation instructions with Codex.")
        case .audioFile:
            return localized("Share the audio, timestamped transcript, and implementation instructions with Codex.")
        }
    }
    var codexPromptTitle: String { localized("Direct Review Handoff") }
    func codexPromptSummary(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return localized("Use the recording and timeline to implement the reviewer's explicit requests directly in code.")
        case .audioFile:
            return localized("Use the audio recording and timestamp-aligned transcript to implement the reviewer's explicit requests directly in code.")
        }
    }
    var includedContents: String { localized("Included") }
    var includedVideo: String { localized("Screen recording or optimized video parts") }
    var includedAudio: String { localized("Audio recording") }
    var includedTimeline: String { localized("Timestamp-aligned transcript") }
    var includedPrompt: String { localized("Direct implementation instructions") }
    var fullPrompt: String { localized("Full Review Instructions") }
    var noTimeline: String { localized("No Timeline") }
    func jumpToSource(for sourceKind: ReviewSourceKind) -> String {
        switch sourceKind {
        case .screenRecording:
            return localized("Jump to video")
        case .audioFile:
            return localized("Jump to audio")
        }
    }
    var copied: String { localized("Copied") }
    var copyCodexPrompt: String { localized("Copy Review Instructions") }
    var shareToChatGPT: String { localized("Share Single Document with ChatGPT") }
    var shareVideoAndReview: String { localized("Share Review with Codex") }
    func shareMediaOnly(for sourceKind: ReviewSourceKind, partCount: Int) -> String {
        switch sourceKind {
        case .screenRecording:
            return partCount > 1
                ? localized("Share Video Parts Only")
                : localized("Share Video Only")
        case .audioFile:
            return localized("Share Audio Only")
        }
    }
    var makeOptimizedVideo: String { localized("Make Optimized Codex Video") }
    var makingOptimizedVideo: String { localized("Making optimized video...") }
    var optimizedVideoRequired: String {
        localized("Prepare smaller video files before sharing the full package. The transcript is already available.")
    }
    var cancelVideoCompression: String { localized("Cancel Video Preparation") }
    var retryVideoCompression: String { localized("Retry Video Preparation") }
    var videoCompressionFailed: String { localized("Video Preparation Failed") }
    var videoCompressionCancelled: String { localized("Video Preparation Cancelled") }
    func videoCompressionTitle(_ snapshot: VideoCompressionSnapshot) -> String {
        switch snapshot.stage {
        case .preparing:
            return localized("Preparing Video")
        case .compressing:
            if let current = snapshot.currentPartDisplayIndex, snapshot.plannedPartCount > 0 {
                return formatted(
                    "Compressing part %1$@ of %2$@",
                    String(current),
                    String(snapshot.plannedPartCount)
                )
            }
            return makingOptimizedVideo
        case .installing:
            return localized("Saving Optimized Videos")
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
        return formatted(
            "Planned %1$@ · completed %2$@ · produced %3$@",
            String(snapshot.plannedPartCount),
            String(snapshot.completedPartCount),
            String(snapshot.producedPartCount)
        )
    }
    func optimizedVideoReady(partCount: Int) -> String {
        partCount > 1
            ? formatted("%@ optimized videos ready", String(partCount))
            : localized("Optimized video ready")
    }
    var optimizedVideoDescription: String {
        localized("Creates 540p, 30 fps copies and splits them by timestamp when a file would exceed 280 MB. Transcription still uses the original audio.")
    }
    var exportJSONDescription: String {
        localized("Developer/automation data with timestamps, transcript rows, and processing metadata.")
    }
    var exportReadableTimelineDescription: String {
        localized("Human-readable timeline with short rows grouped naturally.")
    }
    var exportOriginalTimelineDescription: String {
        localized("Original transcript timeline for subtitles, timestamp checks, and evidence.")
    }
    var exportSRTDescription: String {
        localized("Standard subtitles for video editors and players.")
    }
    var exportVTTDescription: String {
        localized("Subtitle format for web players and browsers.")
    }
    var readableTimelineMarkdown: String { localized("Readable Timeline (.md)") }
    var originalTimelineMarkdown: String { localized("Original Timeline (.md)") }
    var jsonExport: String { localized("JSON (.json)") }
    var srtSubtitles: String { localized("SRT Subtitles (.srt)") }
    var vttWebSubtitles: String { localized("VTT Web Subtitles (.vtt)") }

    var cancel: String { localized("Cancel") }
    var delete: String { localized("Delete") }
    var save: String { localized("Save") }
    var ok: String { localized("OK") }
    var editReviewTitle: String { localized("Edit Review Title") }
    var reviewTitle: String { localized("Review Title") }
    var reviewTitleHelp: String {
        localized("ReviewTrace cannot reliably detect which app was reviewed from the video alone. Name it so you can recognize it later.")
    }
    var deleteReview: String { localized("Delete Review") }
    var deleteReviewConfirmTitle: String { localized("Delete this review?") }
    var deleteReviewConfirmMessage: String {
        localized("This will permanently delete the source file, transcript, and export files for this review.")
    }
    var deleteCompletedTitle: String { localized("Deleted") }
    func deleteReviewCompletedMessage(_ title: String) -> String {
        formatted("%@ has been deleted.", title)
    }

    var settingsTitle: String { localized("Settings") }
    var general: String { localized("General") }
    var appLanguage: String { localized("App Language") }
    var defaultTranscriptionLanguage: String { localized("Default Transcription Language") }
    var exportDefaultFormat: String { localized("Default export format") }
    var privacy: String { localized("Privacy") }
    var localFileStorage: String { localized("Files Stay in the App") }
    var speechRecognitionPrivacy: String { localized("Apple Speech Recognition") }
    var privacyExplanation: String {
        localized("Imported sources, transcripts, and exports are stored in ReviewTrace and leave the app only when you choose to share them.")
    }
    var speechRecognitionPrivacyExplanation: String {
        localized("Speech recognition may use Apple servers depending on the device, language, and network. ReviewTrace does not guarantee on-device-only recognition.")
    }
    var exportStyle: String { localized("Export Style") }
    var structuredJSON: String { localized("Structured JSON Data") }
    var subtitleExports: String { localized("SRT/VTT Subtitles") }
    var dataManagement: String { localized("Data Management") }
    var deleteAllRecordings: String { localized("Delete all recordings") }
    var deleteAllConfirmTitle: String { localized("Delete all reviews?") }
    var deleteAllConfirmMessage: String {
        localized("This will permanently delete every review source file, transcript, and export file.")
    }
    var deleteAllCompletedMessage: String { localized("All reviews have been deleted.") }
}
