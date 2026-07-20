import Foundation

enum BroadcastSessionMetadataStoreError: LocalizedError {
    case missingMetadata(UUID)
    case invalidRelativePath(String)

    var errorDescription: String? {
        switch self {
        case .missingMetadata(let id):
            "Could not find metadata for session \(id.uuidString)."
        case .invalidRelativePath(let path):
            "Invalid session relative path: \(path)"
        }
    }
}

final class BroadcastSessionMetadataStore {
    private let appGroupIdentifier: String
    private let fileManager: FileManager
    private let rootOverride: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        appGroupIdentifier: String = AppConfiguration.appGroupIdentifier,
        fileManager: FileManager = .default,
        rootOverride: URL? = nil
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.fileManager = fileManager
        self.rootOverride = rootOverride
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func rootContainerURL() throws -> URL {
        if let rootOverride {
            try createDirectoryIfNeeded(rootOverride)
            return rootOverride
        }

        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try createDirectoryIfNeeded(documentsURL)
        return documentsURL
    }

    func sessionsRootURL() throws -> URL {
        let url = try rootContainerURL()
            .appendingPathComponent(AppConfiguration.sessionsFolderName, isDirectory: true)
        try createDirectoryIfNeeded(url)
        return url
    }

    func sessionDirectory(for sessionId: UUID) throws -> URL {
        let url = try sessionsRootURL()
            .appendingPathComponent(sessionId.uuidString, isDirectory: true)
        try createDirectoryIfNeeded(url)
        return url
    }

    func createSession(title: String?, warmUpDelay: TimeInterval) throws -> BroadcastSessionMetadata {
        let sessionId = UUID()
        let createdAt = Date()
        let directory = try sessionDirectory(for: sessionId)
        let metadata = BroadcastSessionMetadata(
            sessionId: sessionId,
            title: title,
            sourceKind: .screenRecording,
            createdAt: createdAt,
            broadcastStartedAt: createdAt,
            effectiveReviewStartedAt: createdAt.addingTimeInterval(warmUpDelay),
            warmUpDelay: warmUpDelay,
            firstVideoPresentationTimestamp: nil,
            firstMicPresentationTimestamp: nil,
            videoRelativePath: try relativePath(for: directory.appendingPathComponent("screenRecording.mov")),
            micAudioRelativePath: try relativePath(for: directory.appendingPathComponent("micAudio.m4a")),
            appAudioRelativePath: try relativePath(for: directory.appendingPathComponent("appAudio.m4a")),
            status: .recording,
            errorMessage: nil
        )
        try write(metadata)
        return metadata
    }

    func write(_ metadata: BroadcastSessionMetadata) throws {
        let url = try metadataURL(for: metadata.sessionId)
        let data = try encoder.encode(metadata)
        try data.write(to: url, options: [.atomic])
    }

    func readMetadata(sessionId: UUID) throws -> BroadcastSessionMetadata {
        let url = try metadataURL(for: sessionId)
        guard fileManager.fileExists(atPath: url.path) else {
            throw BroadcastSessionMetadataStoreError.missingMetadata(sessionId)
        }
        return try readMetadata(at: url)
    }

    func readMetadata(at url: URL) throws -> BroadcastSessionMetadata {
        let data = try Data(contentsOf: url)
        return try decoder.decode(BroadcastSessionMetadata.self, from: data)
    }

    func updateStatus(
        sessionId: UUID,
        status: ReviewSessionStatus,
        errorMessage: String? = nil
    ) throws {
        var metadata = try readMetadata(sessionId: sessionId)
        metadata.status = status
        metadata.errorMessage = errorMessage
        try write(metadata)
    }

    func update(_ sessionId: UUID, mutate: (inout BroadcastSessionMetadata) -> Void) throws {
        var metadata = try readMetadata(sessionId: sessionId)
        mutate(&metadata)
        try write(metadata)
    }

    func listSessionMetadata() throws -> [BroadcastSessionMetadata] {
        let root = try sessionsRootURL()
        let sessionDirectories = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return sessionDirectories.compactMap { directory in
            let metadataURL = directory.appendingPathComponent("metadata.json")
            guard fileManager.fileExists(atPath: metadataURL.path) else { return nil }
            return try? readMetadata(at: metadataURL)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func pendingSessions() throws -> [BroadcastSessionMetadata] {
        try listSessionMetadata()
            .filter { $0.status == .pendingProcessing }
    }

    func metadataURL(for sessionId: UUID) throws -> URL {
        try sessionDirectory(for: sessionId)
            .appendingPathComponent("metadata.json")
    }

    func url(for relativePath: String?) throws -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        guard !relativePath.contains("..") else {
            throw BroadcastSessionMetadataStoreError.invalidRelativePath(relativePath)
        }
        return try rootContainerURL().appendingPathComponent(relativePath)
    }

    func relativePath(for url: URL) throws -> String {
        let root = try rootContainerURL().standardizedFileURL
        let target = url.standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard target.path.hasPrefix(rootPath) else {
            return target.lastPathComponent
        }
        return String(target.path.dropFirst(rootPath.count))
    }

    private func createDirectoryIfNeeded(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
