import Foundation

struct VideoPartTimelineGuide {
    func promptBlock(for session: ReviewSession, language: AppLanguage) -> String {
        let parts = splitParts(for: session)
        guard !parts.isEmpty else { return "" }
        let lines = partLines(parts, language: language).joined(separator: "\n")

        if language == .korean {
            return """
            분할 영상 구간표:
            \(lines)
            전사 타임스탬프를 확인할 때는 해당 원본 구간의 파일을 고른 뒤, `원본 타임스탬프 - 파일 시작 시간` 위치로 이동하세요.
            """
        }
        return """
        Split video range map:
        \(lines)
        To inspect a transcript timestamp, choose the file containing that source range and seek to `source timestamp - file start time`.
        """
    }

    func markdownSection(for session: ReviewSession, language: AppLanguage) -> String {
        let parts = splitParts(for: session)
        guard !parts.isEmpty else { return "" }
        let lines = partLines(parts, language: language).joined(separator: "\n")

        if language == .korean {
            return """
            ## 분할 영상 구간표

            \(lines)

            전사 타임스탬프를 확인할 때는 해당 원본 구간의 파일을 고른 뒤, `원본 타임스탬프 - 파일 시작 시간` 위치로 이동하세요.
            """
        }
        return """
        ## Split Video Range Map

        \(lines)

        To inspect a transcript timestamp, choose the file containing that source range and seek to `source timestamp - file start time`.
        """
    }

    private func splitParts(for session: ReviewSession) -> [OptimizedVideoPart] {
        guard session.resolvedSourceKind == .screenRecording else { return [] }
        let parts = session.resolvedOptimizedVideoParts
        return parts.count > 1 ? parts : []
    }

    private func partLines(_ parts: [OptimizedVideoPart], language: AppLanguage) -> [String] {
        parts.map { part in
            let sourceStart = ReviewTimeFormatter.clock(part.startTime)
            let sourceEnd = ReviewTimeFormatter.clock(part.startTime + part.duration)
            let localEnd = ReviewTimeFormatter.clock(part.duration)
            if language == .korean {
                return "- `\(part.url.lastPathComponent)`: 원본 \(sourceStart)-\(sourceEnd) · 파일 내부 00:00-\(localEnd)"
            }
            return "- `\(part.url.lastPathComponent)`: source \(sourceStart)-\(sourceEnd) · local 00:00-\(localEnd)"
        }
    }
}

struct CodexPromptService {
    func generate(for session: ReviewSession, language: AppLanguage = AppConfiguration.defaultAppLanguage) -> String {
        if shouldUseBriefPrompt(for: session) {
            return generateBrief(for: session, language: language)
        }

        switch language {
        case .korean:
            return generateFullKorean(for: session)
        case .english:
            return generateFullEnglish(for: session)
        }
    }

    func generateBrief(for session: ReviewSession, language: AppLanguage = AppConfiguration.defaultAppLanguage) -> String {
        switch language {
        case .korean:
            return generateBriefKorean(for: session)
        case .english:
            return generateBriefEnglish(for: session)
        }
    }

    private func shouldUseBriefPrompt(for session: ReviewSession) -> Bool {
        session.duration > 600 || session.transcriptSegments.map(\.text.count).reduce(0, +) > 6_000
    }

    private func generateFullKorean(for session: ReviewSession) -> String {
        let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
        let timelineLines = readableSegments.map { segment in
            "[\(ReviewTimeFormatter.clock(segment.startTime))] \(segment.text)"
        }
        let sourceIntro: String
        let sourceCaution: String
        let videoPartGuide = VideoPartTimelineGuide().promptBlock(for: session, language: .korean)
        switch session.resolvedSourceKind {
        case .screenRecording:
            sourceIntro = "첨부된 앱 화면 녹화를 리뷰해 주세요."
            sourceCaution = "말하는 사람이 헷갈림, 부족함, 깨짐, 안 보임, 너무 복잡함, 작동하지 않음 등을 언급한 순간을 우선적으로 봐주세요."
        case .audioFile:
            sourceIntro = "첨부된 음성 리뷰 전사를 기준으로 앱 개발 방향과 작업 목록을 정리해 주세요."
            sourceCaution = "화면 영상은 없으므로, 발화 내용에서 확인 가능한 범위 안에서만 제안해 주세요."
        }

        return """
        \(sourceIntro)
        아래 타임스탬프 전사는 사용자가 말한 내용을 읽기 좋게 묶은 타임라인입니다.
        원문에 가까운 전사 행은 full-transcript.md의 "원문 타임라인" 섹션에 남아 있습니다.
        \(sourceCaution)
        \(videoPartGuide)
        수정 제안은 현재 디자인 방향을 유지하고, 가장 안전한 최소 변경부터 제안해 주세요.

        읽기용 리뷰 타임라인:
        \(timelineLines.joined(separator: "\n"))

        요청:
        1. 주요 이슈를 정리해 주세요.
        2. 반복되는 코멘트를 묶어 주세요.
        3. 구현 수준의 수정 방향을 제안해 주세요.
        4. 수정 가능성이 높은 화면/컴포넌트를 짚어 주세요.
        5. Codex가 처리할 우선순위 작업 목록을 만들어 주세요.
        """
    }

    private func generateFullEnglish(for session: ReviewSession) -> String {
        let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
        let timelineLines = readableSegments.map { segment in
            "[\(ReviewTimeFormatter.clock(segment.startTime))] \(segment.text)"
        }
        let sourceIntro: String
        let sourceCaution: String
        let videoPartGuide = VideoPartTimelineGuide().promptBlock(for: session, language: .english)
        switch session.resolvedSourceKind {
        case .screenRecording:
            sourceIntro = "Use this review to improve the app shown in the attached screen recording."
            sourceCaution = "Prioritize moments where the speaker says something is confusing, missing, broken, hard to see, too complex, or not working."
        case .audioFile:
            sourceIntro = "Use this audio review transcript to organize app development direction and implementation tasks."
            sourceCaution = "No screen recording is attached, so only make suggestions that are supported by the spoken transcript."
        }

        return """
        \(sourceIntro)
        The timestamped transcript below is a readable timeline grouped from the speaker's review.
        The closer-to-original rows remain in the "Original Timeline" section of full-transcript.md.
        \(sourceCaution)
        \(videoPartGuide)
        Preserve the current design direction and suggest minimal safe changes first.

        Readable review timeline:
        \(timelineLines.joined(separator: "\n"))

        Please:
        1. Identify the major issues.
        2. Group repeated comments.
        3. Suggest implementation-level fixes.
        4. Identify likely screens/components to modify.
        5. Give a prioritized task list for Codex.
        """
    }

    private func generateBriefKorean(for session: ReviewSession) -> String {
        let ranges = fiveMinuteRanges(for: session, language: .korean)
        let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
        let candidateLines = issueCandidateLines(in: readableSegments, limit: 16)
        let sourceLine = session.resolvedSourceKind == .audioFile
            ? "첨부된 음성 파일과 전체 전사 파일을 함께 검토해 주세요. 화면 영상은 없으므로 발화 내용에서 확인 가능한 범위 안에서만 제안해 주세요."
            : "첨부된 앱 화면 녹화와 전체 전사 파일을 함께 리뷰해 주세요."
        let recordingLine = session.resolvedSourceKind == .audioFile
            ? "- audio 파일: 회의 녹음 또는 음성 리뷰 원본"
            : "- recording 파일: 실제 앱 화면 흐름 확인용"
        let videoPartGuide = VideoPartTimelineGuide().promptBlock(for: session, language: .korean)

        return """
        \(sourceLine)
        이 파일은 요약본이 아니라 Codex에게 작업 방향을 알려주는 프롬프트입니다.

        기본 첨부 파일:
        \(recordingLine)
        - full-transcript.md: 읽기용 타임라인과 원문 타임라인

        \(videoPartGuide)

        선택 첨부 파일:
        - review-data.json: 자동화나 구조화 처리가 필요할 때 참고

        리뷰 길이: \(ReviewTimeFormatter.clock(session.duration))
        원문 타임라인 행 수: \(session.transcriptSegments.count)
        읽기용 타임라인 행 수: \(readableSegments.count)

        주요 구간 index:
        \(ranges.joined(separator: "\n"))

        사용자가 문제라고 말했을 가능성이 높은 문장 후보:
        \(candidateLines.isEmpty ? "- 후보를 자동으로 고르지 못했습니다. 전체 transcript를 기준으로 검토해 주세요." : candidateLines.joined(separator: "\n"))

        요청:
        1. 전체 transcript 파일을 기준으로 주요 UX/UI/버그 이슈를 찾아 주세요.
        2. 반복되는 코멘트를 묶어 주세요.
        3. timestamp를 유지해서 근거를 표시해 주세요.
        4. 구현 수준의 수정 방향을 제안해 주세요.
        5. Codex가 처리할 우선순위 작업 목록을 만들어 주세요.
        """
    }

    private func generateBriefEnglish(for session: ReviewSession) -> String {
        let ranges = fiveMinuteRanges(for: session, language: .english)
        let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
        let candidateLines = issueCandidateLines(in: readableSegments, limit: 16)
        let sourceLine = session.resolvedSourceKind == .audioFile
            ? "Review the attached audio file and full transcript. No screen recording is attached, so only make suggestions supported by the spoken transcript."
            : "Review the attached app screen recording and the full transcript file."
        let recordingLine = session.resolvedSourceKind == .audioFile
            ? "- audio file: original meeting recording or spoken review"
            : "- recording file: use it to inspect the actual app flow"
        let videoPartGuide = VideoPartTimelineGuide().promptBlock(for: session, language: .english)

        return """
        \(sourceLine)
        This file is not a summary. It is a prompt that tells Codex how to use the attached review materials.

        Default attached files:
        \(recordingLine)
        - full-transcript.md: readable timeline and original timeline

        \(videoPartGuide)

        Optional attached files:
        - review-data.json: structured data for automation or deeper processing

        Review duration: \(ReviewTimeFormatter.clock(session.duration))
        Original timeline rows: \(session.transcriptSegments.count)
        Readable timeline rows: \(readableSegments.count)

        Section index:
        \(ranges.joined(separator: "\n"))

        Candidate sentences where the user likely mentioned problems:
        \(candidateLines.isEmpty ? "- No automatic candidates were selected. Review the full transcript." : candidateLines.joined(separator: "\n"))

        Please:
        1. Identify major UX/UI/bug issues from the full transcript.
        2. Group repeated comments.
        3. Preserve timestamps as evidence.
        4. Suggest implementation-level fixes.
        5. Give a prioritized task list for Codex.
        """
    }

    private func fiveMinuteRanges(for session: ReviewSession, language: AppLanguage) -> [String] {
        let sectionLength: TimeInterval = 300
        let maxEndTime = max(session.duration, session.transcriptSegments.map(\.endTime).max() ?? 0)
        guard maxEndTime > 0 else {
            return [language == .korean ? "- 00:00-05:00: transcript 없음" : "- 00:00-05:00: no transcript"]
        }

        var lines: [String] = []
        var start: TimeInterval = 0
        var sectionIndex = 1
        while start < maxEndTime {
            let end = min(start + sectionLength, maxEndTime)
            let count = session.transcriptSegments.filter { $0.startTime >= start && $0.startTime < end }.count
            if language == .korean {
                lines.append("- \(sectionIndex). \(ReviewTimeFormatter.clock(start))-\(ReviewTimeFormatter.clock(end)): \(count)개 타임라인 행")
            } else {
                lines.append("- \(sectionIndex). \(ReviewTimeFormatter.clock(start))-\(ReviewTimeFormatter.clock(end)): \(count) timeline rows")
            }
            start += sectionLength
            sectionIndex += 1
        }
        return lines
    }

    private func issueCandidateLines(in segments: [TranscriptSegment], limit: Int) -> [String] {
        let keywords = [
            "문제", "안 ", "안되", "안 돼", "어색", "중복", "불편", "헷갈", "모르", "이상", "없애", "바꿔", "개선",
            "missing", "broken", "confusing", "hard", "issue", "bug", "not working"
        ]

        return segments
            .filter { segment in
                keywords.contains { segment.text.localizedCaseInsensitiveContains($0) }
            }
            .prefix(limit)
            .map { "- [\(ReviewTimeFormatter.clock($0.startTime))] \($0.text)" }
    }
}
