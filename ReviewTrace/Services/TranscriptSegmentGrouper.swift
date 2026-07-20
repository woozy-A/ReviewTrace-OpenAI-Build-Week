import Foundation

struct TranscriptSegmentGrouper {
    var maxGap: TimeInterval = 1.2
    var maxDuration: TimeInterval = 5
    var maxCharacterCount = 45

    func group(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        let normalized = deduplicate(segments)
            .map { segment in
                let endTime = segment.endTime > segment.startTime ? segment.endTime : segment.startTime + 0.5
                return TranscriptSegment(
                    id: segment.id,
                    startTime: max(0, segment.startTime),
                    endTime: max(0.5, endTime),
                    text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: segment.confidence,
                    isIssueCandidate: false
                )
            }
            .filter { !$0.text.isEmpty }
            .sorted { $0.startTime < $1.startTime }

        var grouped: [TranscriptSegment] = []
        var current: TranscriptSegment?
        var confidenceValues: [Double] = []

        func finishCurrent() {
            guard var finished = current else { return }
            if !confidenceValues.isEmpty {
                finished.confidence = confidenceValues.reduce(0, +) / Double(confidenceValues.count)
            }
            grouped.append(finished)
            current = nil
            confidenceValues = []
        }

        for segment in normalized {
            guard var active = current else {
                current = segment
                confidenceValues = segment.confidence.map { [$0] } ?? []
                continue
            }

            let mergedText = mergeText(active.text, segment.text)
            let shouldStartNewRow =
                segment.startTime - active.endTime > maxGap ||
                segment.endTime - active.startTime > maxDuration ||
                mergedText.count > maxCharacterCount ||
                endsWithSentencePunctuation(active.text)

            if shouldStartNewRow {
                finishCurrent()
                current = segment
                confidenceValues = segment.confidence.map { [$0] } ?? []
            } else {
                active.endTime = max(active.endTime, segment.endTime)
                active.text = mergedText
                active.confidence = nil
                current = active
                if let confidence = segment.confidence {
                    confidenceValues.append(confidence)
                }
            }
        }

        finishCurrent()
        return grouped
    }

    private func deduplicate(_ segments: [TranscriptSegment]) -> [TranscriptSegment] {
        let sorted = segments
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.startTime < $1.startTime }

        var result: [TranscriptSegment] = []
        for segment in sorted {
            if let last = result.last,
               segment.startTime <= last.endTime + 1.5,
               isLikelyDuplicate(last.text, segment.text) {
                if shouldReplaceDuplicate(last, with: segment) {
                    var replacement = segment
                    replacement.startTime = min(last.startTime, segment.startTime)
                    replacement.endTime = max(last.endTime, segment.endTime)
                    result[result.count - 1] = replacement
                }
                continue
            }
            result.append(segment)
        }
        return result
    }

    private func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    private func mergeText(_ lhs: String, _ rhs: String) -> String {
        guard !lhs.isEmpty else { return rhs }
        guard !rhs.isEmpty else { return lhs }

        let lhsWords = lhs.split(separator: " ").map(String.init)
        let rhsWords = rhs.split(separator: " ").map(String.init)
        let maxOverlap = min(lhsWords.count, rhsWords.count)

        if maxOverlap > 0 {
            for overlapCount in stride(from: maxOverlap, through: 1, by: -1) {
                let lhsSuffix = lhsWords.suffix(overlapCount).map(normalizedText).joined()
                let rhsPrefix = rhsWords.prefix(overlapCount).map(normalizedText).joined()
                if lhsSuffix == rhsPrefix {
                    return (lhsWords + rhsWords.dropFirst(overlapCount)).joined(separator: " ")
                }
            }
        }

        return "\(lhs) \(rhs)"
    }

    private func endsWithSentencePunctuation(_ text: String) -> Bool {
        guard let lastCharacter = text.last else { return false }
        return ".?!。？！".contains(lastCharacter)
    }

    private func isLikelyDuplicate(_ lhs: String, _ rhs: String) -> Bool {
        let lhsText = normalizedText(lhs)
        let rhsText = normalizedText(rhs)
        guard !lhsText.isEmpty, !rhsText.isEmpty else { return false }

        if lhsText == rhsText { return true }
        if lhsText.count >= 4, rhsText.contains(lhsText) { return true }
        if rhsText.count >= 4, lhsText.contains(rhsText) { return true }

        let overlapCount = suffixPrefixOverlap(lhsText, rhsText)
        let minimumLength = min(lhsText.count, rhsText.count)
        return overlapCount >= 4 && Double(overlapCount) / Double(max(1, minimumLength)) >= 0.55
    }

    private func shouldReplaceDuplicate(_ current: TranscriptSegment, with candidate: TranscriptSegment) -> Bool {
        let currentText = normalizedText(current.text)
        let candidateText = normalizedText(candidate.text)
        if candidateText.count != currentText.count {
            return candidateText.count > currentText.count
        }
        return (candidate.confidence ?? 0) > (current.confidence ?? 0)
    }

    private func suffixPrefixOverlap(_ lhs: String, _ rhs: String) -> Int {
        let lhsCharacters = Array(lhs)
        let rhsCharacters = Array(rhs)
        let maxOverlap = min(lhsCharacters.count, rhsCharacters.count)
        guard maxOverlap > 0 else { return 0 }

        for overlapCount in stride(from: maxOverlap, through: 1, by: -1) {
            let lhsSuffix = lhsCharacters.suffix(overlapCount)
            let rhsPrefix = rhsCharacters.prefix(overlapCount)
            if Array(lhsSuffix) == Array(rhsPrefix) {
                return overlapCount
            }
        }
        return 0
    }
}

struct ReadableTimelineBuilder {
    var maxGap: TimeInterval = 1.8
    var maxDuration: TimeInterval = 10
    var maxCharacterCount = 100

    func build(from segments: [TranscriptSegment]) -> [TranscriptSegment] {
        let cleaned = segments
            .map(normalized)
            .filter { !isNoise($0.text) }
            .sorted { $0.startTime < $1.startTime }

        var readable: [TranscriptSegment] = []
        var current: TranscriptSegment?
        var confidenceValues: [Double] = []

        func finishCurrent() {
            guard var finished = current else { return }
            if !confidenceValues.isEmpty {
                finished.confidence = confidenceValues.reduce(0, +) / Double(confidenceValues.count)
            }
            readable.append(finished)
            current = nil
            confidenceValues = []
        }

        for segment in cleaned {
            guard var active = current else {
                current = segment
                confidenceValues = segment.confidence.map { [$0] } ?? []
                continue
            }

            let mergedText = mergeText(active.text, segment.text)
            if shouldMerge(active, segment, mergedText: mergedText) {
                let mergedRawText = mergeOptionalText(active.rawText ?? active.text, segment.rawText ?? segment.text)
                active.endTime = max(active.endTime, segment.endTime)
                active.text = mergedText
                active.rawText = mergedRawText
                active.confidence = nil
                current = active
                if let confidence = segment.confidence {
                    confidenceValues.append(confidence)
                }
            } else {
                finishCurrent()
                current = segment
                confidenceValues = segment.confidence.map { [$0] } ?? []
            }
        }

        finishCurrent()
        return readable
    }

    private func normalized(_ segment: TranscriptSegment) -> TranscriptSegment {
        let text = segment.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return TranscriptSegment(
            id: segment.id,
            startTime: max(0, segment.startTime),
            endTime: max(segment.endTime, segment.startTime + 0.5),
            text: text,
            rawText: segment.rawText,
            confidence: segment.confidence,
            isIssueCandidate: segment.isIssueCandidate
        )
    }

    private func shouldMerge(_ active: TranscriptSegment, _ next: TranscriptSegment, mergedText: String) -> Bool {
        let gap = next.startTime - active.endTime
        guard gap <= maxGap else { return false }
        guard next.endTime - active.startTime <= maxDuration else { return false }
        guard mergedText.count <= maxCharacterCount else { return false }
        if endsWithSentencePunctuation(active.text) { return false }

        if active.text.count < 24 { return true }
        if startsWithConnector(next.text) { return true }
        return gap <= 0.5
    }

    private func isNoise(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let meaningfulCharacters = CharacterSet.letters.union(.decimalDigits)
        return !trimmed.unicodeScalars.contains { meaningfulCharacters.contains($0) }
    }

    private func startsWithConnector(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "그리고", "그래서", "근데", "그러면", "그럼", "또", "아니면", "여기", "이거", "저거",
            "and ", "so ", "but ", "then ", "also "
        ]
        return prefixes.contains { prefix in
            trimmed.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil
        }
    }

    private func mergeText(_ lhs: String, _ rhs: String) -> String {
        guard !lhs.isEmpty else { return rhs }
        guard !rhs.isEmpty else { return lhs }

        let lhsWords = lhs.split(separator: " ").map(String.init)
        let rhsWords = rhs.split(separator: " ").map(String.init)
        let maxOverlap = min(lhsWords.count, rhsWords.count)

        if maxOverlap > 0 {
            for overlapCount in stride(from: maxOverlap, through: 1, by: -1) {
                let lhsSuffix = lhsWords.suffix(overlapCount).map(normalizedText).joined()
                let rhsPrefix = rhsWords.prefix(overlapCount).map(normalizedText).joined()
                if lhsSuffix == rhsPrefix {
                    return (lhsWords + rhsWords.dropFirst(overlapCount)).joined(separator: " ")
                }
            }
        }

        return "\(lhs) \(rhs)"
    }

    private func mergeOptionalText(_ lhs: String?, _ rhs: String?) -> String? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return mergeText(lhs, rhs)
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }

    private func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    private func endsWithSentencePunctuation(_ text: String) -> Bool {
        guard let lastCharacter = text.last else { return false }
        return ".?!。？！".contains(lastCharacter)
    }
}
