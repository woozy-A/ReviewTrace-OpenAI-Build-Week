# ReviewTrace 해커톤 촬영 가이드

이 문서는 최종 ReviewTrace-on-ReviewTrace 데모에서 **어느 화면에서 어떤 영어 문장을 말할지**와 완성된 앱을 안전하게 보존하는 방법을 정리합니다.

## 촬영 원칙

- 프로덕션 브랜치는 영어 전사를 포함한 완성 상태로 유지합니다.
- 촬영용 수정 사항을 남겨두기 위해 앱을 미완성 상태로 만들지 않습니다.
- 촬영 직전에만 완성 브랜치에서 별도의 `demo/ui-regression` 브랜치와 Git worktree를 만듭니다.
- 데모 작업공간에서만 눈에 잘 띄고 복구가 쉬운 UI 값을 의도적으로 바꿉니다.
- 영어로 말한 리뷰를 ReviewTrace가 `en-US`로 전사하고, Codex가 그 요청만 반영해 완성값으로 복구하는 과정을 촬영합니다.

현재 완성값은 다음과 같습니다.

- Timeline 읽기용 미리보기 너비: `84pt`
- Export의 **Direct Review Handoff** 설명: 짧은 안내 문장
- **Direct Review Handoff** 제목 스타일: `.headline`

## 0. 촬영 직전에 데모 작업공간 만들기

최종 요청은 나중에 확정합니다. 아래 두 항목은 화면에서 차이가 확실한 예시입니다.

1. Timeline 미리보기 너비를 데모 브랜치에서만 `84pt`에서 `48pt`로 줄입니다.
2. **Direct Review Handoff** 제목을 데모 브랜치에서만 `.headline`에서 `.caption`으로 줄입니다.

완성 브랜치에서 아래처럼 별도 작업공간을 만들 수 있습니다.

```sh
git worktree add ../OpenAi_ReviewTrace_Demo -b demo/ui-regression main
```

의도적인 UI 변경, 데모용 빌드, Codex 복구 작업은 모두 `OpenAi_ReviewTrace_Demo`에서만 진행합니다. 프로덕션 작업공간에는 촬영용 회귀를 커밋하지 않습니다.

## 1. 완료된 리뷰 하나 먼저 만들기

최종 촬영에서는 완료된 리뷰의 Timeline과 Export 화면을 보여줘야 합니다. 새 설치라서 리뷰 목록이 비어 있다면 먼저 20–30초짜리 seed 영상을 만드세요.

1. iPhone 화면 녹화의 마이크를 켭니다.
2. 개인정보가 없는 화면을 천천히 이동합니다.
3. 아래 세 문장을 2초 정도 쉬어가며 말합니다.
   - `This is a test recording.`
   - `I am checking the ReviewTrace home screen.`
   - `The import buttons are easy to find.`
4. ReviewTrace 홈에서 **Language Spoken in This Review → English (en-US)**를 선택합니다.
5. 영상을 가져오고 상태가 **Ready**가 될 때까지 기다립니다.

## 2. 최종 촬영 전 설정

1. 데모 작업공간에서 빌드한 앱을 대상 iPhone에 설치합니다.
2. ReviewTrace **Settings → App Language → English**를 선택합니다.
3. Home에서 **Language Spoken in This Review → English (en-US)**를 선택합니다.
4. 방해금지를 켜고 개인정보가 보이는 화면을 닫습니다.
5. 제어 센터에서 화면 녹화를 길게 누르고 **Microphone On**을 확인합니다.
6. 화면 녹화를 시작합니다.

## 3. 첫 번째 요청을 말할 화면

이동 순서:

`ReviewTrace → Reviews → 완료된 리뷰 선택 → Timeline → Readable`

왼쪽의 폭이 좁아진 세로형 미리보기 이미지가 보이는 전사 행에서 멈추고 말합니다.

- 한국어 뜻: 타임라인 미리보기 이미지가 너무 좁습니다. 더 넓게 해주세요.
- 영어: `The timeline preview image is too narrow. Please make it wider.`
- 발음: `더 타임라인 프리뷰 이미지 이즈 투 내로우. 플리즈 메이크 잇 와이더.`

## 4. 두 번째 요청을 말할 화면

같은 완료 리뷰에서 이동합니다.

`Export → Direct Review Handoff 카드`

작아진 **Direct Review Handoff** 제목이 화면에 또렷하게 보일 때 멈추고 말합니다.

- 한국어 뜻: Direct Review Handoff 제목이 너무 작습니다. 더 크고 굵게 해주세요.
- 영어: `The Direct Review Handoff title is too small. Please make it larger and bold.`
- 발음: `더 다이렉트 리뷰 핸드오프 타이틀 이즈 투 스몰. 플리즈 메이크 잇 라저 앤 볼드.`

마지막으로 같은 화면에서 말합니다.

- 한국어 뜻: 그 외에는 모두 그대로 유지해 주세요.
- 영어: `Please keep everything else unchanged.`
- 발음: `플리즈 킵 에브리씽 엘스 언체인지드.`

그 뒤 화면 녹화를 종료합니다.

## 5. 영어 리뷰를 ReviewTrace로 처리하기

1. ReviewTrace Home으로 돌아옵니다.
2. **English (en-US)**가 선택되어 있는지 다시 확인합니다.
3. **Import Screen Recording**을 누르고 방금 찍은 영상을 선택합니다.
4. 완료 후 **Timeline → Readable**에서 두 영어 요청과 타임스탬프를 확인합니다.
5. **Export → Share Review with Codex**로 녹화, `full-transcript.md`, `codex-prompt.md`를 전달합니다.
6. Codex에는 데모 작업공간만 열고 두 요청 외에는 바꾸지 않도록 합니다.
7. Codex가 미리보기 `84pt`와 제목 `.headline`을 복구하면 빌드와 테스트를 실행합니다.
8. 같은 두 화면을 다시 촬영해 before/after를 남깁니다.

## 6. 최종 요청을 바꾸고 싶을 때

위 두 요청은 추천 예시일 뿐입니다. 촬영 직전에 다른 요청으로 바꿔도 됩니다. 다만 다음 조건을 지키면 영상이 이해하기 쉽습니다.

- 화면만 봐도 before/after 차이가 보여야 합니다.
- 숫자나 글꼴처럼 한두 줄로 안전하게 복구할 수 있어야 합니다.
- 개인정보, 저장 데이터, 전사, 압축 같은 핵심 기능을 일부러 고장 내지 않습니다.
- 프로덕션 브랜치에는 의도적인 회귀를 넣지 않습니다.
