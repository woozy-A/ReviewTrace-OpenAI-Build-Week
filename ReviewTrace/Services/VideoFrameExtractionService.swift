@preconcurrency import AVFoundation
import UIKit

enum VideoFrameExtractionError: LocalizedError, Equatable {
    case invalidTimestamp

    var errorDescription: String? {
        switch self {
        case .invalidTimestamp:
            "The requested video timestamp must be a finite number."
        }
    }
}

protocol VideoFrameExtracting {
    func frame(from videoURL: URL, at timestamp: TimeInterval) async throws -> UIImage
}

struct VideoFrameExtractionService: VideoFrameExtracting {
    var maximumSize: CGSize
    var tolerance: TimeInterval

    init(
        maximumSize: CGSize = CGSize(width: 360, height: 640),
        tolerance: TimeInterval = 0.20
    ) {
        self.maximumSize = maximumSize
        self.tolerance = tolerance
    }

    func frame(from videoURL: URL, at timestamp: TimeInterval) async throws -> UIImage {
        guard timestamp.isFinite else {
            throw VideoFrameExtractionError.invalidTimestamp
        }

        try Task.checkCancellation()

        // Each request owns its generator so cancelling one timeline row cannot
        // cancel frame extraction for another visible row.
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maximumSize

        let safeTolerance = tolerance.isFinite ? max(0, tolerance) : 0
        let toleranceTime = CMTime(seconds: safeTolerance, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = toleranceTime
        generator.requestedTimeToleranceAfter = toleranceTime

        let requestedTime = CMTime(
            seconds: max(0, timestamp),
            preferredTimescale: 600
        )
        let cancellation = ImageGeneratorCancellation(generator: generator)

        do {
            return try await withTaskCancellationHandler(operation: {
                let result = try await generator.image(at: requestedTime)
                try Task.checkCancellation()
                return UIImage(cgImage: result.image)
            }, onCancel: {
                cancellation.cancel()
            })
        } catch {
            if error is CancellationError || Task.isCancelled {
                throw CancellationError()
            }
            throw error
        }
    }
}

private final class ImageGeneratorCancellation: @unchecked Sendable {
    private let generator: AVAssetImageGenerator

    init(generator: AVAssetImageGenerator) {
        self.generator = generator
    }

    func cancel() {
        generator.cancelAllCGImageGeneration()
    }
}

final class TimelineFrameCache: @unchecked Sendable {
    static let shared = TimelineFrameCache()

    private let cache = NSCache<NSString, UIImage>()

    init(
        countLimit: Int = 48,
        totalCostLimit: Int = 24 * 1_024 * 1_024
    ) {
        cache.countLimit = max(0, countLimit)
        cache.totalCostLimit = max(0, totalCostLimit)
    }

    func image(for videoURL: URL, at timestamp: TimeInterval) -> UIImage? {
        guard let key = cacheKey(videoURL: videoURL, timestamp: timestamp) else {
            return nil
        }
        return cache.object(forKey: key)
    }

    func insert(_ image: UIImage, for videoURL: URL, at timestamp: TimeInterval) {
        guard let key = cacheKey(videoURL: videoURL, timestamp: timestamp) else {
            return
        }
        cache.setObject(image, forKey: key, cost: imageCost(image))
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private func cacheKey(videoURL: URL, timestamp: TimeInterval) -> NSString? {
        guard timestamp.isFinite else { return nil }

        let scaledTimestamp = max(0, timestamp) * 10
        guard scaledTimestamp.isFinite,
              scaledTimestamp <= Double(Int.max) else {
            return nil
        }

        let decisecond = Int(scaledTimestamp.rounded())
        let path = videoURL.standardizedFileURL.path
        return "\(path)#\(decisecond)" as NSString
    }

    private func imageCost(_ image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return max(1, cgImage.bytesPerRow * cgImage.height)
        }

        let pixelCount = image.size.width
            * image.size.height
            * image.scale
            * image.scale
        let byteCount = pixelCount * 4
        guard byteCount.isFinite else { return 1 }
        return max(1, Int(min(byteCount, Double(Int.max))))
    }
}

struct TimelineFrameProvider {
    private let extractor: VideoFrameExtracting
    private let cache: TimelineFrameCache

    init(
        extractor: VideoFrameExtracting = VideoFrameExtractionService(),
        cache: TimelineFrameCache = .shared
    ) {
        self.extractor = extractor
        self.cache = cache
    }

    func frame(from videoURL: URL, at timestamp: TimeInterval) async throws -> UIImage {
        guard timestamp.isFinite else {
            throw VideoFrameExtractionError.invalidTimestamp
        }

        try Task.checkCancellation()

        if let cached = cache.image(for: videoURL, at: timestamp) {
            return cached
        }

        let image = try await extractor.frame(from: videoURL, at: timestamp)
        try Task.checkCancellation()
        cache.insert(image, for: videoURL, at: timestamp)
        return image
    }
}
