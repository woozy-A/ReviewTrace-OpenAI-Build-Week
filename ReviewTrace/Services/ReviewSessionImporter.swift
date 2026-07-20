import Foundation

struct ReviewSessionImporter {
    var metadataStore: BroadcastSessionMetadataStore
    var pipeline: ReviewProcessingPipeline

    init(
        metadataStore: BroadcastSessionMetadataStore = BroadcastSessionMetadataStore(),
        pipeline: ReviewProcessingPipeline = ReviewProcessingPipeline()
    ) {
        self.metadataStore = metadataStore
        self.pipeline = pipeline
    }

    func importPendingSessions() async -> [ReviewSession] {
        do {
            let pending = try metadataStore.pendingSessions()
            var sessions: [ReviewSession] = []

            for metadata in pending {
                do {
                    try metadataStore.updateStatus(sessionId: metadata.sessionId, status: .processing)
                    let directory = try metadataStore.sessionDirectory(for: metadata.sessionId)
                    let session = try makeSession(from: metadata)
                    let processed = await pipeline.process(session, outputDirectory: directory)
                    try metadataStore.updateStatus(sessionId: metadata.sessionId, status: processed.status)
                    sessions.append(processed)
                } catch {
                    try? metadataStore.updateStatus(
                        sessionId: metadata.sessionId,
                        status: .failed,
                        errorMessage: error.localizedDescription
                    )
                }
            }

            return sessions
        } catch {
            return []
        }
    }

    private func makeSession(from metadata: BroadcastSessionMetadata) throws -> ReviewSession {
        ReviewSession(
            id: metadata.sessionId,
            title: metadata.title ?? "App Review",
            sourceKind: metadata.sourceKind ?? .screenRecording,
            createdAt: metadata.createdAt,
            broadcastStartedAt: metadata.broadcastStartedAt,
            effectiveReviewStartedAt: metadata.effectiveReviewStartedAt,
            duration: 0,
            warmUpDelay: metadata.warmUpDelay,
            videoURL: try metadataStore.url(for: metadata.videoRelativePath),
            micAudioURL: try metadataStore.url(for: metadata.micAudioRelativePath),
            appAudioURL: try metadataStore.url(for: metadata.appAudioRelativePath),
            status: .processing
        )
    }
}
