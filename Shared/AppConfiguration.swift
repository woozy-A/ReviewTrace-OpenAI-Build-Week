import Foundation

enum AppConfiguration {
    static let appGroupIdentifier = "group.com.example.reviewtrace"
    static let sessionsFolderName = "Sessions"
    static let defaultWarmUpDelay: TimeInterval = 0
    static let defaultLanguageIdentifier = "ko-KR"
    static let secondaryLanguageIdentifier = "en-US"
    static let defaultAppLanguage: AppLanguage = .korean
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable, Hashable {
    case korean = "ko-KR"
    case english = "en-US"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .korean: "한국어 (ko-KR)"
        case .english: "English (en-US)"
        }
    }
}
