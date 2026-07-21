# ReviewTrace Build Week 프로젝트 기획서

> **2026-07-21 범위 안내:** 이 문서는 초기 조사안입니다. Build Week 구현 범위는 `ReviewTrace_OpenAI_Build_Week_Final_Plan.md`가 우선합니다. 아래의 OpenAI 런타임 API·프록시·AI 이슈 카드 계획은 현재 P0 구현 범위가 아닙니다.

> 문서 상태: Build Week 실행 계획 1차안  
> 작성일: 2026-07-21  
> 실제 저장소: 이 문서를 포함한 Git 저장소의 루트
> 권장 출품 트랙: **Developer Tools**

## 0. 문서 표기 규칙

- **[확인됨]** 현재 저장소의 코드, 기존 문서 또는 공식 대회 페이지에서 확인한 내용
- **[계획]** OpenAI Build Week 출품을 위해 새로 구현할 내용
- **[가정]** 대화와 제품 방향을 바탕으로 제안한 내용이며 구현 전 확정이 필요한 내용
- **[확인 필요]** 공식 규칙, 계정, API 또는 배포 환경에서 다시 확인해야 하는 내용

## 1. 한 줄 정의

ReviewTrace는 iPhone 화면 녹화 속 음성 피드백을 영상과 동기화된 전사로 바꾸고, GPT-5.6이 근거 타임스탬프가 있는 리뷰 브리프로 구조화한 뒤, Codex가 바로 수정 작업을 시작할 수 있는 작업 패키지로 전달하는 iOS 개발자 도구다.

## 2. 문제 정의

### 2.1 사용자가 겪는 문제

iOS 앱을 테스트할 때 개발자는 화면을 녹화하며 다음과 같이 자연스럽게 말한다.

- "이 버튼은 너무 아래에 있어서 놓칠 것 같아."
- "위쪽 제목과 아래쪽 내용이 중복돼 보여."
- "여기서 뒤로 갔을 때 이전 상태가 유지되지 않아."
- "검색창을 위로 올리면 더 보기 쉬울 것 같아."

그러나 녹화를 끝낸 뒤 실제 수정 작업으로 연결하려면 다음 수작업이 다시 필요하다.

1. 긴 영상을 반복 재생한다.
2. 피드백을 글로 옮긴다.
3. 문제가 나온 시점을 찾는다.
4. 중복 의견을 정리한다.
5. Codex가 이해할 수 있는 작업 요청으로 다시 작성한다.
6. 영상, 전사, 요청 문서를 따로 전달한다.

### 2.2 기존 도구만으로 부족한 점

- 일반 전사 앱은 음성을 텍스트로 바꾸지만, **앱 화면의 시간축과 개발 작업**을 중심으로 구성하지 않는다.
- 자동 요약은 원문을 지나치게 줄이거나 사용자가 실제로 말하지 않은 결론을 만들 수 있다.
- 화면 녹화와 별도 음성 녹음을 사용하면 두 파일의 싱크가 어긋날 수 있다.
- 대용량 영상을 그대로 Codex나 ChatGPT에 전달하기 어렵다.
- 영상 1개를 보고 사람이 다시 "무엇을 고칠지" 정리하는 시간이 많이 든다.

### 2.3 해결 원칙

ReviewTrace는 다음 세 층을 분리한다.

1. **원문 증거층:** 영상, 원문 전사, 정확한 타임스탬프를 보존한다.
2. **읽기층:** 짧게 끊긴 전사를 사람이 읽기 좋은 행으로 묶는다.
3. **AI 작업층:** GPT-5.6이 근거 타임스탬프를 유지한 리뷰 브리프를 만들고, Codex용 작업 지시로 변환한다.

AI 결과가 틀릴 수 있으므로 AI 요약이 원문을 대체해서는 안 된다. 모든 이슈는 가능한 한 원문 세그먼트와 타임스탬프를 근거로 가져야 한다.

## 3. 실제 사용자 흐름

### 3.1 화면 녹화 리뷰

1. 사용자가 iPhone 기본 화면 기록을 시작하고 마이크를 켠다.
2. 리뷰할 앱을 1분에서 최대 60분 정도 사용하면서 말로 피드백을 남긴다.
3. 녹화를 종료하고 ReviewTrace를 연다.
4. 사진 보관함에서 화면 녹화 영상을 가져온다.
5. ReviewTrace가 영상의 오디오를 추출하고, 침묵 지점을 고려해 청크로 나눈다.
6. 청크를 순차 전사하고 결과를 중간 저장한다.
7. 사용자는 원문 타임라인 또는 읽기용 타임라인을 확인한다.
8. 타임스탬프를 누르면 영상이 같은 시점으로 이동한다.
9. **[계획]** 사용자가 `AI 리뷰 만들기`를 명시적으로 누른다.
10. **[계획]** 앱은 기본적으로 영상이 아닌 전사와 타임스탬프만 GPT-5.6 분석 서비스로 전송한다.
11. **[계획]** GPT-5.6이 주요 문제, 긍정 피드백, 수정 제안, 근거 타임스탬프를 구조화한다.
12. 사용자가 결과를 검토하고 필요한 이슈를 선택한다.
13. ReviewTrace가 영상 또는 분할 영상, 전사, 선택 이슈, Codex 프롬프트를 작업 패키지로 만든다.
14. 사용자가 패키지를 Codex에 전달한다.
15. Codex가 저장소를 읽고 선택된 문제를 구현, 빌드, 테스트한다.

### 3.2 음성 파일 보조 흐름

1. 개발 회의 또는 음성 리뷰 파일을 가져온다.
2. 동일한 청크 전사와 읽기용 타임라인을 생성한다.
3. **[계획]** GPT-5.6이 결정 사항, 미해결 질문, 구현 작업을 구조화한다.
4. Codex 작업 패키지로 전달한다.

이 흐름은 보조 기능이다. 제품의 주 정체성은 화면 녹화 기반 앱 리뷰다.

## 4. 기존 구현 기능

아래 항목은 현재 저장소의 코드와 `Docs/` 문서에서 확인된 기능이다.

### 4.1 가져오기와 로컬 보관

- [확인됨] SwiftUI 기반 iPhone 앱
- [확인됨] 사진 보관함의 화면 녹화 영상 가져오기
- [확인됨] 음성 파일 가져오기 보조 기능
- [확인됨] 세션별 로컬 폴더 저장
- [확인됨] 개별 리뷰 삭제, 전체 리뷰 삭제 확인, 작업 취소 시 정리
- [확인됨] 한국어 기본 UI와 영어 UI 선택

### 4.2 전사 파이프라인

- [확인됨] AVFoundation 기반 오디오 추출
- [확인됨] Apple Speech 기반 한국어/영어 전사
- [확인됨] 약 45초 목표의 침묵 인식 청크 분할
- [확인됨] 1.5초 중첩으로 경계에서 잘리는 발화 보호
- [확인됨] 중첩 구간의 중복 전사 제거
- [확인됨] 청크 내부 시간을 원본 영상 시간으로 병합
- [확인됨] 청크별 전사 JSON 중간 저장과 실패 청크 재시도
- [확인됨] 실제 가져온 영상에서 mock transcript로 대체하지 않는 정책

### 4.3 리뷰 확인

- [확인됨] AVPlayer 영상 미리보기
- [확인됨] 원문 타임라인과 읽기용 타임라인
- [확인됨] 타임스탬프 선택 시 영상 seek
- [확인됨] 전사 내용을 바탕으로 한 보조적인 리뷰 제목 생성
- [확인됨] 전사 진행률, 실패 청크 표시, 취소와 재시도

### 4.4 내보내기

- [확인됨] Codex 프롬프트 Markdown
- [확인됨] 전체/읽기용/원문 타임라인 Markdown
- [확인됨] ChatGPT용 단일 Markdown
- [확인됨] 구조화 JSON
- [확인됨] SRT/VTT 자막
- [확인됨] 영상과 문서를 묶은 Codex 작업 패키지 공유
- [확인됨] 280 MB를 넘는 원본 영상을 540p, 30fps로 별도 압축
- [확인됨] 압축 진행률, 취소, 재시도, 파일 분할
- [확인됨] 분할 영상별 원본 시간과 파일 내부 시간 구간표

### 4.5 안정성과 테스트

- [확인됨] 전사와 영상 압축의 독립 실행
- [확인됨] 동시 작업 충돌 방지
- [확인됨] 압축 결과의 트랜잭션 방식 교체와 실패 시 이전 결과 보존
- [확인됨] 압축 정책과 타임라인 병합 XCTest 8개
- [확인됨] 개인정보 안내: 로컬 우선이지만 Apple Speech가 환경에 따라 Apple 서비스를 사용할 수 있음을 표시

### 4.6 아직 없는 핵심 기능

- [확인됨] OpenAI API를 호출하는 런타임 AI 분석 기능은 아직 없다.
- [확인됨] 현재 Codex Brief의 이슈 후보는 키워드 기반 보조 로직이며 GPT 요약이 아니다.
- [확인됨] AI 이슈 추출, 이슈 그룹화, 자동 스크린샷 추출은 아직 MVP 밖이다.
- [확인됨] Codex가 iOS 앱 안에서 대상 저장소를 직접 수정하는 구조는 아니다.

## 5. OpenAI Build Week에서 새로 구현할 기능

Build Week에서는 기능 수를 늘리기보다 **전사에서 코드 수정으로 이어지는 하나의 완성된 AI 루프**를 만든다.

### 5.1 GPT-5.6 리뷰 브리프

**[계획, P0]** 사용자가 요청한 경우 전사 데이터를 GPT-5.6에 보내 다음 구조로 받는다.

- 한 문단 리뷰 요약
- 주요 UX/UI/버그 이슈
- 긍정적으로 평가한 부분
- 중복 의견 그룹
- 각 이슈의 근거 타임스탬프와 원문 세그먼트 ID
- 구현 수준의 수정 제안
- 우선순위가 있는 Codex 작업 목록
- 불확실하거나 추가 확인이 필요한 항목

중요한 제한:

- 원문 전사는 수정하거나 덮어쓰지 않는다.
- 근거가 없는 이슈는 낮은 신뢰도 또는 `확인 필요`로 표시한다.
- 모델 응답은 자유 형식 텍스트가 아니라 검증 가능한 구조화 JSON으로 받는다.
- 분석 실패 시 기존 전사와 내보내기 기능은 그대로 사용할 수 있어야 한다.

### 5.2 근거 연결형 이슈 카드

**[계획, P0]** AI가 만든 이슈 카드를 누르면 해당 타임스탬프로 영상을 이동한다.

이슈 카드에는 다음만 간결하게 표시한다.

- 제목
- 심각도 또는 우선순위
- 사용자 발언 요약
- 근거 시간
- 추천 수정 방향
- `Codex에 보낼 작업에 포함` 토글

### 5.3 Codex 작업 패키지 2.0

**[계획, P0]** 사용자가 선택한 이슈만 포함하는 패키지를 생성한다.

```text
ReviewTrace-Codex-Package/
  codex-task.md
  ai-review-brief.json
  full-transcript.md
  review-data.json
  recording.mp4 또는 codex-video-*.mp4
```

`codex-task.md`에는 다음을 포함한다.

- 해결할 문제와 우선순위
- 근거 타임스탬프
- 사용자의 실제 발언
- 모델의 제안과 `AI 제안` 표시
- 기대 동작과 acceptance criteria
- 분할 영상 구간표
- Codex에게 먼저 저장소를 읽고 기존 구조를 따르라는 지시

### 5.4 AI 전송 동의와 개인정보 경계

**[계획, P0]** 첫 AI 분석 전에 다음을 명확히 보여준다.

- 전사 내용이 OpenAI 분석을 위해 전송된다는 사실
- 기본적으로 영상 파일은 전송하지 않는다는 사실
- 계정, 이메일, 사내 정보 등이 전사에 포함될 수 있다는 경고
- 사용자가 취소해도 로컬 전사 결과는 유지된다는 사실

**[가정]** 해커톤 버전은 전체 영상을 GPT-5.6에 직접 보내지 않고, 텍스트와 타임스탬프만 전송한다. 영상 장면 분석은 제출 이후 확장으로 둔다.

### 5.5 분석 캐시, 실패, 재시도

**[계획, P1]** 같은 전사와 같은 프롬프트 버전이면 저장된 AI 결과를 재사용한다.

- 분석 중 진행 상태
- 네트워크 오류와 모델 오류의 사용자용 메시지
- 취소와 재시도
- 응답 스키마 검증 실패 시 안전한 실패 처리
- 모델명, 프롬프트 버전, 생성 시각 저장

### 5.6 제출 이후 확장 후보

- **[가정, P2]** 이슈 타임스탬프의 영상 프레임 자동 추출
- **[가정, P2]** 프로젝트별 용어 사전
- **[가정, P2]** 여러 리뷰에서 반복되는 이슈 비교
- **[가정, P2]** GitHub 저장소/PR과 직접 연결
- **[가정, P2]** 온디바이스 전사 백엔드 추가

## 6. GPT-5.6과 Codex의 역할

### 6.1 GPT-5.6: 리뷰 해석기

GPT-5.6은 앱 안에서 **이미 생성된 전사를 개발 작업 문맥으로 해석**한다.

- 말이 매끄럽지 않아도 문맥상 같은 문제를 묶는다.
- 문제, 긍정 피드백, 제안, 단순 관찰을 구분한다.
- 모든 결론을 가능한 한 타임스탬프 근거에 연결한다.
- 바로 구현 가능한 작업과 제품 결정이 필요한 질문을 분리한다.
- 구조화 JSON을 생성한다.

GPT-5.6이 하지 않는 일:

- 원문 전사를 삭제하거나 대체하지 않는다.
- 근거 없이 앱 코드를 보았다고 가정하지 않는다.
- 사용자 승인 없이 영상을 업로드하지 않는다.
- iOS 저장소를 직접 수정하지 않는다.

### 6.2 Codex: 제작자이자 실행기

Codex에는 두 역할이 있다.

1. **Build Week 제작 역할 [확인됨]**
   - 기존 ReviewTrace 저장소 분석
   - 기능 구현과 리팩터링
   - Xcode 빌드, XCTest, 시뮬레이터 검증
   - 문서와 제출 자료 작성
   - `/feedback`으로 핵심 작업 세션 기록

2. **ReviewTrace 사용자 워크플로 역할 [계획]**
   - ReviewTrace가 만든 작업 패키지 읽기
   - 타임스탬프와 사용자 발언을 증거로 사용
   - 대상 앱 저장소 구조를 먼저 파악
   - 선택된 이슈를 구현
   - 테스트와 빌드 수행
   - 변경 내용과 검증 결과 보고

### 6.3 두 도구의 경계

```text
사람의 음성 피드백
    -> ReviewTrace 전사
    -> GPT-5.6 구조화/우선순위화
    -> 사용자 검토와 선택
    -> Codex 작업 패키지
    -> Codex 코드 수정/검증
```

GPT-5.6은 무엇을 고칠지 정리하고, Codex는 실제 저장소에서 어떻게 고칠지 판단하고 실행한다. 최종 선택권은 사용자에게 있다.

## 7. iOS 앱 구조

### 7.1 현재 구조

```text
ReviewTraceApp
  -> AppView
      -> HomeView / StartReviewView
      -> ProcessingView
      -> ReviewListView
      -> ReviewDetailView
      -> SettingsView

ReviewTraceStore (@Observable, MainActor)
  -> ReviewSessionPersistence
  -> ReviewProcessingPipeline
      -> AudioExtractionService
      -> AudioChunkingService
      -> SpeechTranscriptionService
      -> TranscriptSegmentGrouper
      -> CodexPromptService
      -> Markdown / JSON / Subtitle Export Services
  -> VideoCompressionService
```

저장소는 SwiftUI, async/await, AVFoundation, Speech, PhotosUI를 사용한다. 세션의 원본과 파생 파일은 앱 Documents의 `Sessions/<session-id>/`에 저장된다.

### 7.2 Build Week 추가 구조

```text
ReviewDetailView
  -> AI Review 탭 또는 Review Brief 화면
      -> AIReviewViewModel/Store 상태
          -> AIReviewService protocol
              -> ReviewTrace API Proxy [계획]
                  -> OpenAI GPT-5.6
          -> AIReviewBriefPersistence
          -> CodexTaskPackageService
```

권장 책임 분리:

- `AIReviewService`: 요청 생성, 네트워크 호출, 응답 디코딩
- `AIReviewPromptBuilder`: 모델 지시와 전사 입력 생성
- `AIReviewSchema`: 구조화 응답 Codable 모델
- `AIReviewValidator`: 존재하지 않는 세그먼트 ID와 잘못된 시간 제거
- `AIReviewBriefPersistence`: 세션 폴더에 결과와 provenance 저장
- `CodexTaskPackageService`: 사용자가 선택한 이슈만 패키징

### 7.3 API 키와 서버

- **[계획]** OpenAI API 키를 iOS 앱 번들에 넣지 않는다.
- **[가정]** 최소한의 서버 프록시 또는 서버리스 함수를 두고 앱은 단기 인증 토큰으로 호출한다.
- **[확인 필요]** 실제 배포 플랫폼과 인증 방식은 아직 결정되지 않았다.
- **[확인 필요]** Build Week 계정에서 사용할 정확한 GPT-5.6 API 모델 ID와 Structured Outputs 지원 방식은 구현 시점의 공식 개발자 문서로 확인한다.

## 8. 데이터 모델

### 8.1 현재 핵심 모델

| 모델 | 역할 |
|---|---|
| `ReviewSession` | 미디어, 전사, 내보내기 URL, 상태를 가진 리뷰 단위 |
| `TranscriptSegment` | 원본 영상 기준 시작/종료 시간과 전사 텍스트 |
| `AudioChunk` | 오디오 분할 파일, 원본 오프셋, 상태, 청크 전사 |
| `ReviewProcessingSnapshot` | 전사 단계, 청크 진행률, 실패 정보 |
| `VideoCompressionSnapshot` | 압축 단계, 파일 분할 진행률, 오류 정보 |
| `OptimizedVideoPart` | 분할 영상의 인덱스, 원본 시작 시간, 길이, 파일 크기 |
| `ReviewIssue` | 미래 이슈 표현을 위한 기존 모델; 현재 AI 분석의 결과 모델은 아님 |

### 8.2 Build Week 신규 모델 제안

```swift
struct AIReviewBrief: Identifiable, Codable {
    let id: UUID
    let sessionID: UUID
    let summary: String
    let issues: [AIReviewIssue]
    let positiveFeedback: [AIFeedbackItem]
    let tasks: [CodexTask]
    let openQuestions: [String]
    let provenance: AIProvenance
}

struct AIReviewIssue: Identifiable, Codable {
    let id: UUID
    let title: String
    let category: IssueCategory
    let severity: IssueSeverity
    let confidence: Double
    let description: String
    let recommendation: String
    let evidence: [TranscriptEvidence]
}

struct TranscriptEvidence: Codable {
    let segmentID: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let quote: String
}

struct CodexTask: Identifiable, Codable {
    let id: UUID
    let priority: Int
    let title: String
    let instruction: String
    let acceptanceCriteria: [String]
    let evidenceSegmentIDs: [UUID]
}

struct AIProvenance: Codable {
    let model: String
    let promptVersion: String
    let transcriptFingerprint: String
    let generatedAt: Date
}

enum AIAnalysisState: Codable {
    case idle
    case preparing
    case analyzing
    case completed
    case failed(message: String)
    case cancelled
}
```

### 8.3 검증 규칙

- 응답의 `segmentID`는 현재 세션에 실제 존재해야 한다.
- 시작/종료 시간은 영상 길이 안에 있어야 한다.
- 인용문이 원문과 다르면 UI에는 원문을 우선 표시한다.
- 심각도와 신뢰도는 모델의 판단임을 명시한다.
- 프롬프트가 바뀌거나 전사가 바뀌면 기존 AI 캐시를 무효화한다.

## 9. 구현 우선순위

공식 제출 마감은 **2026-07-21 17:00 PDT**, 한국 시간으로 **2026-07-22 09:00 KST**다. 따라서 P0만 완성해도 하나의 명확한 데모가 되도록 범위를 제한한다.

### P0. 제출 가능한 핵심 루프

1. 현재 동작 버전을 커밋하고 Build Week 작업 브랜치를 만든다.
2. GPT-5.6 API 모델 ID와 Structured Outputs 예제를 공식 문서에서 확인한다.
3. API 키를 숨기는 최소 프록시를 구성한다.
4. `AIReviewBrief` JSON 스키마와 검증기를 만든다.
5. 실제 전사 세션을 GPT-5.6으로 분석한다.
6. 이슈 카드와 근거 타임스탬프 이동을 구현한다.
7. 선택 이슈 기반 `codex-task.md`와 패키지를 생성한다.
8. 네트워크 실패, 취소, 재시도, 개인정보 동의를 구현한다.
9. 실제 iPhone에서 1분 30초 샘플 전체 흐름을 검증한다.
10. README, 공개 저장소, 3분 미만 데모 영상을 준비한다.

### P1. 신뢰성과 설명력

1. AI 응답 캐시와 provenance 저장
2. 잘못된 세그먼트 ID/시간 검증 테스트
3. 프롬프트 스냅샷 테스트
4. AI 결과를 JSON/Markdown으로 개별 내보내기
5. 데모용 실패 복구 시나리오 점검

### P2. 제출 이후

1. 타임스탬프 스크린샷 추출
2. 여러 리뷰의 반복 이슈 그룹화
3. 프로젝트별 용어 사전
4. GitHub/PR 연동
5. 오프라인 전사 엔진 선택지

### 이번 제출에서 하지 않을 것

- ReplayKit 실시간 화면 녹화 재도입
- 실시간 자막
- 영상 편집기
- 자동 코드 수정 기능을 iOS 앱 안에 직접 내장
- 여러 AI 에이전트를 동시에 운영하는 복잡한 구조
- 근거 없는 완전 자동 승인/수정

## 10. 데모 시나리오

공식 요구사항에 맞춰 공개 YouTube 데모는 3분 미만으로 제작한다.

### 0:00-0:20 문제

- 앱을 테스트하며 말한 피드백은 영상 안에 남지만, 다시 정리해 Codex에 전달하는 데 시간이 걸린다.
- ReviewTrace는 녹화에서 코드 작업까지 이어지는 경로를 만든다.

### 0:20-0:55 기존 전사 기능

- 실제 1분 30초 화면 녹화를 가져온다.
- 처리된 리뷰에서 원문/읽기용 타임라인을 보여준다.
- 타임스탬프를 눌러 영상이 같은 시점으로 이동하는 것을 보여준다.

### 0:55-1:35 GPT-5.6 분석

- `AI 리뷰 만들기`를 누른다.
- 전사만 전송된다는 개인정보 안내를 짧게 보여준다.
- GPT-5.6이 만든 주요 이슈, 긍정 피드백, 작업 목록을 보여준다.
- 이슈의 근거 시간을 눌러 원본 영상으로 이동한다.

### 1:35-2:10 Codex 작업 패키지

- 수정할 이슈 두 개를 선택한다.
- `Codex 작업 패키지 만들기`를 누른다.
- 패키지 안의 `codex-task.md`, 전사, 영상/분할 영상 구간표를 보여준다.

### 2:10-2:40 Codex 실행

- Codex가 패키지와 대상 저장소를 읽는다.
- 타임스탬프 근거를 확인하고 기존 코드 구조에 맞게 수정 계획 또는 실제 변경을 만든다.
- 빌드/테스트 결과를 짧게 보여준다.

### 2:40-2:55 결과

- "말하면서 리뷰하고, GPT-5.6이 정리하고, Codex가 구현한다"는 전후 흐름을 한 화면으로 요약한다.

### 데모 안정성 원칙

- 실제 가져온 영상과 실제 전사 결과를 사용한다.
- 네트워크 분석 결과는 촬영 전에 한 번 생성해 캐시해 둔다.
- mock transcript를 실제 처리 결과처럼 보여주지 않는다.
- API 호출이 실패해도 기존 전사와 Codex 패키지가 동작하는 모습을 유지한다.

## 11. 해커톤 제출 체크리스트

### 11.1 공식 요구사항 [확인됨]

- [ ] OpenAI Build Week 참가 등록 및 공식 규칙 확인
- [ ] 법적 성년 및 참가 가능 지역 확인; 대한민국은 참가 지역 목록에 포함
- [ ] 제출 마감 확인: 2026-07-21 17:00 PDT / 2026-07-22 09:00 KST
- [ ] 트랙 선택: **Developer Tools**
- [ ] Codex와 GPT-5.6을 사용한 실행 가능한 프로젝트
- [ ] 프로젝트 설명 작성: 문제, 해결책, 동작 방식
- [ ] 3분 미만의 공개 YouTube 데모 영상
- [ ] 영상 음성에서 Codex와 GPT-5.6을 어떻게 사용했는지 설명
- [ ] 심사용 코드 저장소 URL 제공
- [ ] 공개 저장소라면 관련 라이선스 포함
- [ ] 비공개 저장소라면 `testing@devpost.com`, `build-week-event@openai.com`에 공유
- [ ] README에 설치, 실행, 샘플 데이터, 테스트 방법 작성
- [ ] Codex가 가속한 부분, 주요 결정, GPT-5.6/Codex 사용 위치 설명
- [ ] 핵심 기능을 만든 Codex 세션에서 `/feedback`을 실행하고 Session ID 제출
- [ ] 개발자 도구 설치 방법, 지원 플랫폼, 심사위원이 재빌드 없이 시험할 방법 제공

### 11.2 ReviewTrace 제품 준비 [계획]

- [ ] 실제 iPhone에서 영상 가져오기부터 AI 리뷰까지 성공
- [ ] 한국어 전사와 타임스탬프 싱크 확인
- [ ] GPT-5.6 결과가 실제 세그먼트 ID와 시간만 참조하는지 확인
- [ ] AI 분석 실패/취소/재시도 확인
- [ ] 사용자가 AI 전송을 명시적으로 승인하는지 확인
- [ ] OpenAI API 키가 앱, Git 기록, 로그에 없는지 확인
- [ ] Codex 작업 패키지의 모든 파일이 열리는지 확인
- [ ] 280 MB 초과 영상의 압축/분할/구간표 확인
- [ ] XCTest와 iPhone 빌드 통과
- [ ] 앱 화면에 mock 문장이나 내부 디버그 문구가 없는지 확인

### 11.3 저장소와 제출 자료 [계획]

- [ ] 현재 미커밋 변경을 검토하고 의미 있는 단위로 커밋
- [ ] 저장소 이름과 앱 이름 표기를 `ReviewTrace`로 통일
- [ ] `README.md`에 1분 퀵스타트 추가
- [ ] `LICENSE` 추가 또는 라이선스 정책 확정
- [ ] `PRIVACY.md` 또는 README 개인정보 항목 작성
- [ ] 샘플 영상/전사는 개인정보가 없는 자료만 사용
- [ ] 앱 스크린샷 3-5장 준비
- [ ] 아키텍처 다이어그램 1장 준비
- [ ] Devpost 설명문과 100자 내외 한 줄 소개 준비
- [ ] 공개 YouTube 링크가 로그아웃 상태에서도 재생되는지 확인
- [ ] 저장소를 새 환경에서 따라 할 수 있는지 확인

### 11.4 확인 필요

- [ ] [확인 필요] Devpost 제출 폼의 필수 질문과 글자 수 제한 최종 확인
- [ ] [확인 필요] 팀원/개인 출품 정보 입력 방식 확인
- [ ] [확인 필요] 정확한 GPT-5.6 API 모델 ID와 사용 한도 확인
- [ ] [확인 필요] 심사위원용 TestFlight가 필요한지, 로컬 데모 영상만으로 충분한지 결정
- [ ] [확인 필요] 서버 프록시의 공개 데모 기간과 비용 제한 설정

## 12. 성공 기준

Build Week 버전은 다음이 한 번에 보이면 성공이다.

1. 실제 화면 녹화가 실제 한국어 타임라인으로 전사된다.
2. GPT-5.6이 원문 근거를 가진 이슈와 작업 목록을 만든다.
3. 이슈의 시간을 누르면 원본 영상의 같은 시점으로 이동한다.
4. 사용자가 선택한 이슈만 Codex 작업 패키지에 들어간다.
5. Codex가 패키지만 보고 대상 앱의 수정 작업을 시작할 수 있다.
6. AI가 실패해도 원문 전사와 기존 내보내기는 손상되지 않는다.

## 13. 출처

- [OpenAI Build Week 공식 페이지](https://openai.com/build-week/)
- [OpenAI Build Week Devpost 요구사항](https://openai.devpost.com/)
- 저장소 기준 문서: `Docs/ProductVision.md`, `Docs/TechnicalArchitecture.md`, `Docs/MVPChecklist.md`, `Docs/AppStorePrivacyNotes.md`
- 저장소 기준 코드: `Shared/ReviewModels.swift`, `ReviewTrace/Services/ReviewProcessingPipeline.swift`, `ReviewTrace/Services/ExportServices.swift`, `ReviewTrace/Services/CodexPromptService.swift`, `ReviewTrace/App/ReviewTraceStore.swift`
