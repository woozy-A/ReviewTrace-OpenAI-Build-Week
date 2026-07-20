import Foundation

enum ReviewFixtures {
    static func sampleSession() -> ReviewSession {
        let segments = [
            TranscriptSegment(startTime: 8, endTime: 12, text: "홈 화면에서 바람 방향 카드가 먼저 보여야 하는데 잘 안 보임", confidence: 0.92),
            TranscriptSegment(startTime: 26, endTime: 31, text: "Tack 버튼이 중요한데 너무 아래에 있어서 놓칠 것 같음", confidence: 0.9),
            TranscriptSegment(startTime: 64, endTime: 69, text: "초보자는 bearing이라는 용어를 모를 것 같음", confidence: 0.88),
            TranscriptSegment(startTime: 108, endTime: 113, text: "뒤로가기 했을 때 이전 상태가 유지되지 않음", confidence: 0.86)
        ]

        var session = ReviewSession(
            title: "SailCoach 리뷰",
            createdAt: Date(),
            duration: 204,
            warmUpDelay: 0,
            transcriptSegments: segments,
            issueCandidates: [],
            status: .ready
        )
        session.codexPrompt = CodexPromptService().generate(for: session)
        return session
    }
}
