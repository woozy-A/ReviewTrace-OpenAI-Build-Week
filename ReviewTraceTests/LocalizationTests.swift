import XCTest
@testable import ReviewTrace

final class LocalizationTests: XCTestCase {
    func testAppCopyLoadsEnglishAndKoreanFromStringCatalog() {
        let english = AppCopy(language: .english)
        let korean = AppCopy(language: .korean)

        XCTAssertEqual(english.homeTab, "Home")
        XCTAssertEqual(korean.homeTab, "홈")
        XCTAssertEqual(english.shareOptionsTitle, "Direct Review Handoff")
        XCTAssertEqual(korean.shareOptionsTitle, "직접 리뷰 전달")
    }

    func testLocalizedFormatsPreserveValuesInBothLanguages() {
        let english = AppCopy(language: .english)
        let korean = AppCopy(language: .korean)

        XCTAssertEqual(english.recentReviewsLimit(5), "5 Recent Reviews")
        XCTAssertEqual(korean.recentReviewsLimit(5), "최근 리뷰 5개")
        XCTAssertEqual(english.transcriptCount(3), "3 transcript segments")
        XCTAssertEqual(korean.transcriptCount(3), "전사 3개")
    }

    func testModelStatusUsesTheSameCatalog() {
        XCTAssertEqual(ReviewSessionStatus.ready.displayName(language: .english), "Ready")
        XCTAssertEqual(ReviewSessionStatus.ready.displayName(language: .korean), "완료")
    }
}
