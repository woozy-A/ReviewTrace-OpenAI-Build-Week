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

        return """
        \(directReviewInstructions(for: session, language: .korean))

        아래 타임스탬프 전사는 리뷰어가 말한 내용을 읽기 좋게 묶은 타임라인입니다.
        원문에 가까운 전사 행은 full-transcript.md의 "원문 타임라인" 섹션에 남아 있습니다.

        읽기용 리뷰 타임라인:
        \(timelineLines.joined(separator: "\n"))
        """
    }

    private func generateFullEnglish(for session: ReviewSession) -> String {
        let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
        let timelineLines = readableSegments.map { segment in
            "[\(ReviewTimeFormatter.clock(segment.startTime))] \(segment.text)"
        }

        return """
        \(directReviewInstructions(for: session, language: .english))

        The timestamped transcript below is a readable timeline grouped from the reviewer's speech.
        The closer-to-original rows remain in the "Original Timeline" section of full-transcript.md.

        Readable review timeline:
        \(timelineLines.joined(separator: "\n"))
        """
    }

    private func generateBriefKorean(for session: ReviewSession) -> String {
        let ranges = fiveMinuteRanges(for: session, language: .korean)
        let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
        let recordingLine = session.resolvedSourceKind == .audioFile
            ? "- audio 파일: 리뷰어가 말한 내용의 원본"
            : "- recording 파일 또는 분할 영상: 실제 화면 상태와 조작 흐름 확인용"

        return """
        \(directReviewInstructions(for: session, language: .korean))

        이 프롬프트는 전체 전사를 중복해서 넣지 않는 긴 리뷰용 전달문입니다.
        구현 전에 full-transcript.md 전체를 읽어 주세요.

        기본 첨부 파일:
        \(recordingLine)
        - full-transcript.md: 읽기용 타임라인과 원문 타임라인

        선택 첨부 파일:
        - review-data.json: 자동화나 구조화 처리가 필요할 때 참고

        리뷰 길이: \(ReviewTimeFormatter.clock(session.duration))
        원문 타임라인 행 수: \(session.transcriptSegments.count)
        읽기용 타임라인 행 수: \(readableSegments.count)

        주요 구간 index:
        \(ranges.joined(separator: "\n"))
        """
    }

    private func generateBriefEnglish(for session: ReviewSession) -> String {
        let ranges = fiveMinuteRanges(for: session, language: .english)
        let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
        let recordingLine = session.resolvedSourceKind == .audioFile
            ? "- audio file: the original record of what the reviewer said"
            : "- recording file or split video parts: inspect the actual screen state and interaction flow"

        return """
        \(directReviewInstructions(for: session, language: .english))

        This handoff omits the full transcript body for a long review.
        Read all of full-transcript.md before implementing changes.

        Default attached files:
        \(recordingLine)
        - full-transcript.md: readable timeline and original timeline

        Optional attached files:
        - review-data.json: structured data for automation or deeper processing

        Review duration: \(ReviewTimeFormatter.clock(session.duration))
        Original timeline rows: \(session.transcriptSegments.count)
        Readable timeline rows: \(readableSegments.count)

        Section index:
        \(ranges.joined(separator: "\n"))
        """
    }

    // STUDY: 전체/긴 리뷰 경로가 갈라져도 근거와 최종 판단 계약은 한곳에서 공유합니다.
    private func directReviewInstructions(for session: ReviewSession, language: AppLanguage) -> String {
        let videoPartGuide = VideoPartTimelineGuide().promptBlock(for: session, language: language)

        switch language {
        case .korean:
            let sourceContract: String
            let visualReferenceRule: String
            let ambiguityEvidence: String

            switch session.resolvedSourceKind {
            case .screenRecording:
                sourceContract = """
                첨부 자료는 하나의 실제 기기 리뷰입니다.
                - 영상은 화면 상태와 조작 흐름의 기준입니다.
                - 타임스탬프 전사는 리뷰어가 실제로 말한 내용의 기준입니다.
                - 저장소는 구현 맥락의 기준입니다.
                - 무엇을 최종 제품에 반영할지는 사람 리뷰어가 결정합니다.
                """
                visualReferenceRule = "“여기”, “이 버튼”, “아까 화면” 같은 표현은 같은 타임스탬프의 영상을 확인한 뒤 해석해 주세요."
                ambiguityEvidence = "영상, 전사, 저장소"
            case .audioFile:
                sourceContract = """
                첨부 자료는 화면 영상이 없는 음성 리뷰입니다.
                - 첨부 음성과 타임스탬프 전사는 리뷰어가 실제로 말한 내용의 기준입니다.
                - 저장소는 구현 맥락의 기준입니다.
                - 화면 상태와 조작 흐름을 보여 주는 영상 근거는 없습니다. 이를 추정하지 마세요.
                - 무엇을 최종 제품에 반영할지는 사람 리뷰어가 결정합니다.
                """
                visualReferenceRule = "“여기”, “이 버튼”, “아까 화면” 같은 시각적 표현은 전사와 저장소만으로 대상을 확정할 수 있을 때만 구현하고, 그렇지 않으면 모호한 항목으로 남겨 주세요."
                ambiguityEvidence = "음성, 전사, 저장소"
            }

            return """
            현재 열려 있는 저장소의 앱을 수정해 주세요.

            \(sourceContract)

            \(videoPartGuide)

            작업 규칙:
            1. 저장소의 AGENTS.md, README, 로컬 지침과 현재 아키텍처를 먼저 읽어 주세요.
            2. \(visualReferenceRule)
            3. 명확하게 요청된 수정은 직접 구현해 주세요.
            4. 칭찬, 화면 설명, 단순 내레이션, 해결되지 않은 고민은 작업으로 만들지 마세요.
            5. 모든 문장을 독립 작업으로 바꾸지 말고, 명확한 요청만 처리해 주세요.
            6. 나중에 나온 명시적 정정은 앞선 요청보다 우선합니다.
            7. 기존 디자인과 아키텍처 안에서 가장 작고 안전한 변경을 우선해 주세요.
            8. \(ambiguityEvidence)를 확인해도 모호한 항목만 질문으로 남겨 주세요.
            9. 수정 후 빌드와 관련 테스트를 실행해 주세요.
            10. 완료 보고에는 대응한 타임스탬프, 변경 파일, 검증 결과, 남은 모호한 항목을 포함해 주세요.
            """

        case .english:
            let sourceContract: String
            let visualReferenceRule: String
            let ambiguityEvidence: String

            switch session.resolvedSourceKind {
            case .screenRecording:
                sourceContract = """
                Treat the attachments as one real-device review record.
                - The video is the source of truth for screen state and interaction flow.
                - The timestamped transcript is the source of truth for what the reviewer said.
                - The repository is the source of truth for implementation context.
                - The human reviewer makes the final product decision.
                """
                visualReferenceRule = "Resolve phrases such as “this,” “here,” and “that button” by inspecting the video at the same timestamp."
                ambiguityEvidence = "the video, transcript, and repository"
            case .audioFile:
                sourceContract = """
                This is an audio-only review with no screen recording attached.
                - The attached audio and timestamped transcript are the source of truth for what the reviewer said.
                - The repository is the source of truth for implementation context.
                - There is no visual evidence for screen state or interaction flow. Do not infer it.
                - The human reviewer makes the final product decision.
                """
                visualReferenceRule = "For visual phrases such as “this,” “here,” and “that button,” implement only when the transcript and repository identify the target; otherwise report the item as ambiguous."
                ambiguityEvidence = "the audio, transcript, and repository"
            }

            return """
            Modify the app in the currently open repository using this review.

            \(sourceContract)

            \(videoPartGuide)

            Working rules:
            1. Read AGENTS.md, README, local instructions, and the existing architecture first.
            2. \(visualReferenceRule)
            3. Implement explicit requested changes directly.
            4. Do not turn praise, screen description, narration, or unresolved brainstorming into tasks.
            5. Do not convert every sentence into a separate task; act only on clear requests.
            6. A later explicit correction overrides an earlier request.
            7. Prefer the smallest safe change consistent with the current design and architecture.
            8. Ask only about items that remain ambiguous after checking \(ambiguityEvidence).
            9. Build and run relevant tests after editing.
            10. In the final report, map addressed timestamps to changed files and verification results, and list anything still ambiguous.
            """
        }
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

}
