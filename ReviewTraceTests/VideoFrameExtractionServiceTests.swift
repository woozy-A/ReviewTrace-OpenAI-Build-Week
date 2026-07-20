import UIKit
import XCTest
@testable import ReviewTrace

final class VideoFrameExtractionServiceTests: XCTestCase {
    private let firstVideoURL = URL(fileURLWithPath: "/tmp/reviewtrace-frame-first.mov")
    private let secondVideoURL = URL(fileURLWithPath: "/tmp/reviewtrace-frame-second.mov")

    func testDefaultExtractionConfigurationIsBoundedAndTolerant() {
        let service = VideoFrameExtractionService()

        XCTAssertEqual(service.maximumSize, CGSize(width: 360, height: 640))
        XCTAssertEqual(service.tolerance, 0.20, accuracy: 0.001)
    }

    func testCacheUsesVideoPathAndDecisecondKey() {
        let cache = TimelineFrameCache()
        let image = UIImage()

        cache.insert(image, for: firstVideoURL, at: 14.11)

        XCTAssertTrue(cache.image(for: firstVideoURL, at: 14.14) === image)
        XCTAssertNil(cache.image(for: firstVideoURL, at: 14.19))
        XCTAssertNil(cache.image(for: secondVideoURL, at: 14.14))
    }

    func testProviderReusesCachedFrameWithoutExtractingAgain() async throws {
        let expectedImage = UIImage()
        let extractor = CountingFrameExtractor(image: expectedImage)
        let provider = TimelineFrameProvider(
            extractor: extractor,
            cache: TimelineFrameCache()
        )

        let first = try await provider.frame(from: firstVideoURL, at: 2.01)
        let second = try await provider.frame(from: firstVideoURL, at: 2.04)

        XCTAssertTrue(first === expectedImage)
        XCTAssertTrue(second === expectedImage)
        XCTAssertEqual(extractor.callCount, 1)
    }

    func testServiceRejectsNonFiniteTimestampBeforeReadingVideo() async {
        let service = VideoFrameExtractionService()

        do {
            _ = try await service.frame(from: firstVideoURL, at: .nan)
            XCTFail("Expected a non-finite timestamp to be rejected.")
        } catch let error as VideoFrameExtractionError {
            XCTAssertEqual(error, .invalidTimestamp)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancelledExtractionIsNotCachedAndRetryCanSucceed() async throws {
        let expectedImage = UIImage()
        let extractor = CancelThenSucceedFrameExtractor(image: expectedImage)
        let provider = TimelineFrameProvider(
            extractor: extractor,
            cache: TimelineFrameCache()
        )

        do {
            _ = try await provider.frame(from: firstVideoURL, at: 8.0)
            XCTFail("Expected the first extraction to be cancelled.")
        } catch is CancellationError {
            // Cancellation is transient and must not become a cached failure.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let retried = try await provider.frame(from: firstVideoURL, at: 8.0)
        let cached = try await provider.frame(from: firstVideoURL, at: 8.0)

        XCTAssertTrue(retried === expectedImage)
        XCTAssertTrue(cached === expectedImage)
        XCTAssertEqual(extractor.callCount, 2)
    }

    func testAlreadyCancelledProviderRequestDoesNotStartExtraction() async {
        let extractor = CountingFrameExtractor(image: UIImage())
        let provider = TimelineFrameProvider(
            extractor: extractor,
            cache: TimelineFrameCache()
        )

        let task = Task { () throws -> UIImage in
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }
            return try await provider.frame(from: firstVideoURL, at: 1.0)
        }

        do {
            _ = try await task.value
            XCTFail("Expected the provider request to remain cancelled.")
        } catch is CancellationError {
            XCTAssertEqual(extractor.callCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class CountingFrameExtractor: VideoFrameExtracting {
    private(set) var callCount = 0
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func frame(from videoURL: URL, at timestamp: TimeInterval) async throws -> UIImage {
        callCount += 1
        return image
    }
}

private final class CancelThenSucceedFrameExtractor: VideoFrameExtracting {
    private(set) var callCount = 0
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func frame(from videoURL: URL, at timestamp: TimeInterval) async throws -> UIImage {
        callCount += 1
        if callCount == 1 {
            throw CancellationError()
        }
        return image
    }
}
