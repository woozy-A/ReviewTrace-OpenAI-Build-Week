import Foundation
import XCTest
@testable import ReviewTrace

final class ReviewSessionLanguageTests: XCTestCase {
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
}
