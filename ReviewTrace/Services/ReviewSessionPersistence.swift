import Foundation

struct ReviewSessionPersistence {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> [ReviewSession] {
        let url = try libraryURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode([ReviewSession].self, from: data)
    }

    func save(_ sessions: [ReviewSession]) throws {
        let url = try libraryURL()
        let data = try encoder.encode(sessions)
        try data.write(to: url, options: [.atomic])
    }

    func deleteLibrary() throws {
        let url = try libraryURL()
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func libraryURL() throws -> URL {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReviewTraceLibrary", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("sessions.json")
    }
}
