import XCTest
@testable import ReviewTrace

final class VideoCompressionPolicyTests: XCTestCase {
    private let policy = VideoCompressionPolicy.codex

    func testCodexPolicyUsesStableSizeAndEncodingTargets() {
        XCTAssertEqual(policy.maximumPartSize, 280_000_000)
        XCTAssertEqual(policy.targetVideoBitRate, 2_700_000)
        XCTAssertEqual(policy.targetAudioBitRate, 128_000)
        XCTAssertEqual(policy.targetFrameRate, 30)
        XCTAssertEqual(policy.targetLandscapeWidth, 960)
        XCTAssertEqual(policy.targetLandscapeHeight, 540)
        XCTAssertEqual(policy.planningSafetyRatio, 0.90, accuracy: 0.001)
    }

    func testPlannedPartCountAcrossSupportedReviewLengths() {
        XCTAssertEqual(policy.plannedPartCount(duration: 10 * 60, hasAudio: true), 1)
        XCTAssertEqual(policy.plannedPartCount(duration: 20 * 60, hasAudio: true), 2)
        XCTAssertEqual(policy.plannedPartCount(duration: 30 * 60, hasAudio: true), 3)
        XCTAssertEqual(policy.plannedPartCount(duration: 60 * 60, hasAudio: true), 6)
    }

    func testFileSizeBoundaryIsDeterministic() {
        XCTAssertFalse(policy.requiresCompression(fileSize: 280_000_000))
        XCTAssertTrue(policy.requiresCompression(fileSize: 280_000_001))
        XCTAssertEqual(
            policy.maximumPlannedPartDuration(hasAudio: true),
            712.87,
            accuracy: 0.02
        )
    }

    func testSplitVideoGuideMapsSourceAndLocalRanges() {
        let session = ReviewSession(
            title: "Test Review",
            duration: 1_200,
            optimizedVideoParts: [
                OptimizedVideoPart(
                    index: 0,
                    url: URL(fileURLWithPath: "/tmp/codex-video-01.mp4"),
                    startTime: 0,
                    duration: 600,
                    fileSize: 200_000_000
                ),
                OptimizedVideoPart(
                    index: 1,
                    url: URL(fileURLWithPath: "/tmp/codex-video-02.mp4"),
                    startTime: 600,
                    duration: 600,
                    fileSize: 200_000_000
                )
            ]
        )

        let guide = VideoPartTimelineGuide().promptBlock(for: session, language: .korean)

        XCTAssertTrue(guide.contains("codex-video-01.mp4"))
        XCTAssertTrue(guide.contains("00:00-10:00"))
        XCTAssertTrue(guide.contains("codex-video-02.mp4"))
        XCTAssertTrue(guide.contains("10:00-20:00"))
        XCTAssertTrue(guide.contains("원본 타임스탬프 - 파일 시작 시간"))
    }
}
