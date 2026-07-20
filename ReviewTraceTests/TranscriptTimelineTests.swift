import XCTest
@testable import ReviewTrace

final class TranscriptTimelineTests: XCTestCase {
    func testChunkOverlapRemovesDuplicateSpeech() {
        let segments = [
            segment(0, 2, "검색 기능을 위로 올려야 해", confidence: 0.7),
            segment(1.9, 4, "검색 기능을 위로 올려야 해", confidence: 0.9)
        ]

        let result = TranscriptSegmentGrouper().group(segments)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "검색 기능을 위로 올려야 해")
        XCTAssertEqual(result[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(result[0].endTime, 4, accuracy: 0.001)
    }

    func testShortConsecutiveFragmentsBecomeOneTimelineRow() {
        let segments = [
            segment(0, 0.8, "이 버튼은"),
            segment(1, 1.8, "너무 아래에 있어요")
        ]

        let result = TranscriptSegmentGrouper().group(segments)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "이 버튼은 너무 아래에 있어요")
    }

    func testSentenceBoundaryStartsANewTimelineRow() {
        let segments = [
            segment(0, 1, "첫 화면입니다."),
            segment(1.1, 2, "다음 화면입니다")
        ]

        let result = TranscriptSegmentGrouper().group(segments)

        XCTAssertEqual(result.map(\.text), ["첫 화면입니다.", "다음 화면입니다"])
    }

    func testReadableTimelineDropsPunctuationOnlyNoise() {
        let segments = [
            segment(0, 0.5, "."),
            segment(0.6, 2, "검색창 위치를 바꾸면 좋겠어요")
        ]

        let result = ReadableTimelineBuilder().build(from: segments)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].text, "검색창 위치를 바꾸면 좋겠어요")
    }

    private func segment(
        _ startTime: TimeInterval,
        _ endTime: TimeInterval,
        _ text: String,
        confidence: Double? = nil
    ) -> TranscriptSegment {
        TranscriptSegment(
            startTime: startTime,
            endTime: endTime,
            text: text,
            confidence: confidence
        )
    }
}
