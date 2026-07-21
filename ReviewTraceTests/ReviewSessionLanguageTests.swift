import Foundation
import XCTest
@testable import ReviewTrace

final class ReviewSessionLanguageTests: XCTestCase {
    func testDefaultAppLanguageUsesKoreanOnlyForKoreanPreferredLanguage() {
        XCTAssertEqual(
            AppConfiguration.appLanguage(forPreferredLanguageIdentifier: "ko"),
            .korean
        )
        XCTAssertEqual(
            AppConfiguration.appLanguage(forPreferredLanguageIdentifier: "ko-KR"),
            .korean
        )
        XCTAssertEqual(
            AppConfiguration.appLanguage(forPreferredLanguageIdentifier: "ko_KR"),
            .korean
        )
    }

    func testDefaultAppLanguageUsesEnglishForEveryOtherPreferredLanguage() {
        XCTAssertEqual(
            AppConfiguration.appLanguage(forPreferredLanguageIdentifier: "en-US"),
            .english
        )
        XCTAssertEqual(
            AppConfiguration.appLanguage(forPreferredLanguageIdentifier: "ja-JP"),
            .english
        )
        XCTAssertEqual(
            AppConfiguration.appLanguage(forPreferredLanguageIdentifier: nil),
            .english
        )
    }

    @MainActor
    func testStoreUsesPreferredLanguageDefaultWhenNoAppLanguageWasSaved() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = ReviewTraceStore(
            userDefaults: userDefaults,
            defaultAppLanguage: .english
        )

        XCTAssertEqual(store.appLanguage, .english)
        XCTAssertEqual(store.transcriptionLanguage, .english)
        XCTAssertNil(userDefaults.string(forKey: "ReviewTrace.appLanguage"))
        XCTAssertNil(userDefaults.string(forKey: "ReviewTrace.transcriptionLanguage"))
    }

    @MainActor
    func testSavedAppLanguageStillOverridesThePreferredLanguageDefault() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set(
            AppLanguage.korean.rawValue,
            forKey: "ReviewTrace.appLanguage"
        )

        let store = ReviewTraceStore(
            userDefaults: userDefaults,
            defaultAppLanguage: .english
        )

        XCTAssertEqual(store.appLanguage, .korean)
        XCTAssertEqual(store.transcriptionLanguage, .korean)
    }

    @MainActor
    func testReviewLanguageFollowsAppLanguageUntilTheUserChoosesAnOverride() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = ReviewTraceStore(userDefaults: userDefaults)
        XCTAssertEqual(store.transcriptionLanguage, store.appLanguage)
        XCTAssertNil(userDefaults.string(forKey: "ReviewTrace.transcriptionLanguage"))

        store.setAppLanguage(.english)

        XCTAssertEqual(store.appLanguage, .english)
        XCTAssertEqual(store.transcriptionLanguage, .english)
        XCTAssertNil(userDefaults.string(forKey: "ReviewTrace.transcriptionLanguage"))

        let restoredStore = ReviewTraceStore(userDefaults: userDefaults)
        XCTAssertEqual(restoredStore.appLanguage, .english)
        XCTAssertEqual(restoredStore.transcriptionLanguage, .english)
    }

    @MainActor
    func testExplicitReviewLanguageIsPreservedWhenAppLanguageChanges() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = ReviewTraceStore(userDefaults: userDefaults)
        store.setAppLanguage(.english)
        store.setTranscriptionLanguage(.korean)
        store.setAppLanguage(.korean)
        store.setAppLanguage(.english)

        XCTAssertEqual(store.appLanguage, .english)
        XCTAssertEqual(store.transcriptionLanguage, .korean)
        XCTAssertEqual(
            userDefaults.string(forKey: "ReviewTrace.transcriptionLanguage"),
            AppLanguage.korean.rawValue
        )

        let restoredStore = ReviewTraceStore(userDefaults: userDefaults)
        XCTAssertEqual(restoredStore.appLanguage, .english)
        XCTAssertEqual(restoredStore.transcriptionLanguage, .korean)
    }

    func testLegacySessionWithoutTranscriptionLanguageDefaultsToKorean() throws {
        let session = ReviewSession(title: "Legacy Review")
        let encoded = try JSONEncoder().encode(session)
        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "transcriptionLanguage")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let decoded = try JSONDecoder().decode(ReviewSession.self, from: legacyData)

        XCTAssertNil(decoded.transcriptionLanguage)
        XCTAssertEqual(decoded.resolvedTranscriptionLanguage, .korean)
        XCTAssertEqual(decoded.transcriptionLocaleIdentifier, "ko-KR")
    }

    func testEnglishSessionPreservesTranscriptionLanguageThroughCodingRoundTrip() throws {
        let session = ReviewSession(
            title: "English Review",
            sourceKind: .audioFile,
            transcriptionLanguage: .english
        )

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(ReviewSession.self, from: encoded)

        XCTAssertEqual(decoded.transcriptionLanguage, .english)
        XCTAssertEqual(decoded.resolvedTranscriptionLanguage, .english)
        XCTAssertEqual(decoded.transcriptionLocaleIdentifier, "en-US")
    }

    func testChunkTranscriptCachePathsDoNotCollideAcrossLanguages() throws {
        let sessionDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: sessionDirectory) }

        let chunk = AudioChunk(
            url: sessionDirectory.appendingPathComponent("chunk-003.m4a"),
            index: 3,
            startOffset: 90,
            duration: 45
        )
        let service = AudioChunkingService()

        let koreanURL = try service.transcriptURL(
            for: chunk,
            in: sessionDirectory,
            localeIdentifier: "ko-KR"
        )
        let englishURL = try service.transcriptURL(
            for: chunk,
            in: sessionDirectory,
            localeIdentifier: "en-US"
        )

        XCTAssertNotEqual(koreanURL, englishURL)
        XCTAssertEqual(koreanURL.lastPathComponent, "chunk-003-transcript-ko-KR.json")
        XCTAssertEqual(englishURL.lastPathComponent, "chunk-003-transcript-en-US.json")
    }

    private func makeIsolatedUserDefaults() throws -> (UserDefaults, String) {
        let suiteName = "ReviewSessionLanguageTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return (userDefaults, suiteName)
    }
}
