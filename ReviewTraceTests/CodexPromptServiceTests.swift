import Foundation
import XCTest
@testable import ReviewTrace

final class CodexPromptServiceTests: XCTestCase {
    private let service = CodexPromptService()

    func testKoreanFullAndBriefScreenPromptsShareDirectHandoffContract() {
        let session = makeSession(sourceKind: .screenRecording)

        for prompt in koreanPrompts(for: session) {
            XCTAssertTrue(prompt.contains("영상은 화면 상태와 조작 흐름의 기준입니다."))
            XCTAssertTrue(prompt.contains("타임스탬프 전사는 리뷰어가 실제로 말한 내용의 기준입니다."))
            XCTAssertTrue(prompt.contains("저장소는 구현 맥락의 기준입니다."))
            XCTAssertTrue(prompt.contains("무엇을 최종 제품에 반영할지는 사람 리뷰어가 결정합니다."))
            XCTAssertTrue(prompt.contains("같은 타임스탬프의 영상을 확인"))
            XCTAssertTrue(prompt.contains("명확하게 요청된 수정은 직접 구현"))
            XCTAssertTrue(prompt.contains("칭찬, 화면 설명, 단순 내레이션, 해결되지 않은 고민은 작업으로 만들지 마세요."))
            XCTAssertTrue(prompt.contains("모든 문장을 독립 작업으로 바꾸지 말고"))
            XCTAssertTrue(prompt.contains("나중에 나온 명시적 정정은 앞선 요청보다 우선"))
            XCTAssertTrue(prompt.contains("가장 작고 안전한 변경"))
            XCTAssertTrue(prompt.contains("수정 후 빌드와 관련 테스트를 실행"))
            XCTAssertTrue(prompt.contains("대응한 타임스탬프, 변경 파일, 검증 결과, 남은 모호한 항목"))
        }
    }

    func testEnglishFullAndBriefScreenPromptsShareDirectHandoffContract() {
        let session = makeSession(sourceKind: .screenRecording)

        for prompt in englishPrompts(for: session) {
            XCTAssertTrue(prompt.contains("The video is the source of truth for screen state and interaction flow."))
            XCTAssertTrue(prompt.contains("The timestamped transcript is the source of truth for what the reviewer said."))
            XCTAssertTrue(prompt.contains("The repository is the source of truth for implementation context."))
            XCTAssertTrue(prompt.contains("The human reviewer makes the final product decision."))
            XCTAssertTrue(prompt.contains("inspecting the video at the same timestamp"))
            XCTAssertTrue(prompt.contains("Implement explicit requested changes directly."))
            XCTAssertTrue(prompt.contains("Do not turn praise, screen description, narration, or unresolved brainstorming into tasks."))
            XCTAssertTrue(prompt.contains("Do not convert every sentence into a separate task"))
            XCTAssertTrue(prompt.contains("A later explicit correction overrides an earlier request."))
            XCTAssertTrue(prompt.contains("Prefer the smallest safe change"))
            XCTAssertTrue(prompt.contains("Build and run relevant tests after editing."))
            XCTAssertTrue(prompt.contains("addressed timestamps to changed files and verification results"))
        }
    }

    func testKoreanAudioOnlyPromptsDoNotClaimVisualEvidence() {
        let session = makeSession(sourceKind: .audioFile)

        for prompt in koreanPrompts(for: session) {
            XCTAssertTrue(prompt.contains("화면 영상이 없는 음성 리뷰"))
            XCTAssertTrue(prompt.contains("영상 근거는 없습니다. 이를 추정하지 마세요."))
            XCTAssertTrue(prompt.contains("전사와 저장소만으로 대상을 확정할 수 있을 때만 구현"))
            XCTAssertTrue(prompt.contains("무엇을 최종 제품에 반영할지는 사람 리뷰어가 결정합니다."))
            XCTAssertFalse(prompt.contains("영상은 화면 상태와 조작 흐름의 기준입니다."))
            XCTAssertFalse(prompt.contains("같은 타임스탬프의 영상을 확인"))
            XCTAssertFalse(prompt.contains("분할 영상 구간표"))
        }
    }

    func testEnglishAudioOnlyPromptsDoNotClaimVisualEvidence() {
        let session = makeSession(sourceKind: .audioFile)

        for prompt in englishPrompts(for: session) {
            XCTAssertTrue(prompt.contains("audio-only review with no screen recording attached"))
            XCTAssertTrue(prompt.contains("There is no visual evidence for screen state or interaction flow. Do not infer it."))
            XCTAssertTrue(prompt.contains("implement only when the transcript and repository identify the target"))
            XCTAssertTrue(prompt.contains("The human reviewer makes the final product decision."))
            XCTAssertFalse(prompt.contains("The video is the source of truth"))
            XCTAssertFalse(prompt.contains("inspecting the video at the same timestamp"))
            XCTAssertFalse(prompt.contains("Split video range map"))
        }
    }

    func testLegacyAnalysisFirstInstructionsAreAbsentFromEveryPromptPath() {
        let prompts = allPromptPaths(for: makeSession(sourceKind: .screenRecording))
        let forbiddenPhrases = [
            "주요 이슈를 정리",
            "반복되는 코멘트를 묶어",
            "우선순위 작업 목록",
            "문장 후보",
            "Identify the major issues",
            "Identify major UX/UI/bug issues",
            "Group repeated comments",
            "prioritized task list",
            "Candidate sentences",
            "severity"
        ]

        for prompt in prompts {
            for phrase in forbiddenPhrases {
                XCTAssertFalse(prompt.localizedCaseInsensitiveContains(phrase), "Unexpected legacy phrase: \(phrase)")
            }
        }
    }

    func testSplitVideoRangeGuideSurvivesFullAndBriefPromptPaths() {
        let session = makeSession(
            sourceKind: .screenRecording,
            duration: 90,
            optimizedVideoParts: [
                OptimizedVideoPart(
                    index: 0,
                    url: URL(fileURLWithPath: "/tmp/codex-video-01.mp4"),
                    startTime: 0,
                    duration: 45,
                    fileSize: 200_000_000
                ),
                OptimizedVideoPart(
                    index: 1,
                    url: URL(fileURLWithPath: "/tmp/codex-video-02.mp4"),
                    startTime: 45,
                    duration: 45,
                    fileSize: 200_000_000
                )
            ]
        )

        let koreanPrompts = [
            service.generate(for: session, language: .korean),
            service.generateBrief(for: session, language: .korean)
        ]
        let englishPrompts = [
            service.generate(for: session, language: .english),
            service.generateBrief(for: session, language: .english)
        ]

        for prompt in koreanPrompts {
            XCTAssertTrue(prompt.contains("codex-video-01.mp4"))
            XCTAssertTrue(prompt.contains("codex-video-02.mp4"))
            XCTAssertTrue(prompt.contains("원본 타임스탬프 - 파일 시작 시간"))
        }
        for prompt in englishPrompts {
            XCTAssertTrue(prompt.contains("codex-video-01.mp4"))
            XCTAssertTrue(prompt.contains("codex-video-02.mp4"))
            XCTAssertTrue(prompt.contains("source timestamp - file start time"))
        }
    }

    func testGenerateAutomaticallyUsesBriefPathForLongReview() {
        let session = makeSession(sourceKind: .screenRecording, duration: 601)

        let koreanPrompt = service.generate(for: session, language: .korean)
        let englishPrompt = service.generate(for: session, language: .english)

        XCTAssertTrue(koreanPrompt.contains("긴 리뷰용 전달문"))
        XCTAssertTrue(englishPrompt.contains("omits the full transcript body for a long review"))
        XCTAssertFalse(koreanPrompt.contains("[00:18] 상단 초록 버튼을 조금 더 크게 만들어 주세요."))
        XCTAssertFalse(englishPrompt.contains("[00:18] 상단 초록 버튼을 조금 더 크게 만들어 주세요."))
    }

    func testFullPromptEmbedsReadableTimelineWithTimestamp() {
        let session = makeSession(sourceKind: .screenRecording)

        let koreanPrompt = service.generate(for: session, language: .korean)
        let englishPrompt = service.generate(for: session, language: .english)

        XCTAssertTrue(koreanPrompt.contains("[00:18] 상단 초록 버튼을 조금 더 크게 만들어 주세요."))
        XCTAssertTrue(englishPrompt.contains("[00:18] 상단 초록 버튼을 조금 더 크게 만들어 주세요."))
    }

    private func koreanPrompts(for session: ReviewSession) -> [String] {
        [
            service.generate(for: session, language: .korean),
            service.generateBrief(for: session, language: .korean)
        ]
    }

    private func englishPrompts(for session: ReviewSession) -> [String] {
        [
            service.generate(for: session, language: .english),
            service.generateBrief(for: session, language: .english)
        ]
    }

    private func allPromptPaths(for session: ReviewSession) -> [String] {
        koreanPrompts(for: session) + englishPrompts(for: session)
    }

    private func makeSession(
        sourceKind: ReviewSourceKind,
        duration: TimeInterval = 90,
        optimizedVideoParts: [OptimizedVideoPart]? = nil
    ) -> ReviewSession {
        ReviewSession(
            title: "Build Week Review",
            sourceKind: sourceKind,
            duration: duration,
            videoURL: sourceKind == .screenRecording
                ? URL(fileURLWithPath: "/tmp/review-recording.mov")
                : nil,
            optimizedVideoParts: optimizedVideoParts,
            micAudioURL: sourceKind == .audioFile
                ? URL(fileURLWithPath: "/tmp/review-audio.m4a")
                : nil,
            transcriptSegments: [
                TranscriptSegment(
                    startTime: 18,
                    endTime: 22,
                    text: "상단 초록 버튼을 조금 더 크게 만들어 주세요."
                )
            ]
        )
    }
}
