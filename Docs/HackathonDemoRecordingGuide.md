# ReviewTrace 해커톤 촬영 가이드

이 문서는 최종 ReviewTrace-on-ReviewTrace 데모에서 **어느 화면에서 어떤 영어 문장을 말할지** 고정한 촬영 순서입니다.

## 먼저 알아둘 점

- 최종 요청 두 개는 촬영을 위해 일부러 아직 수정하지 않았습니다.
- 첫 번째 대상은 읽기용 타임라인 왼쪽 미리보기의 현재 너비 `72pt`입니다.
- 두 번째 대상은 Export 화면의 **Direct Review Handoff** 아래 설명입니다.
- 앱 표시 언어와 전사 언어는 별개입니다. 최종 영상에서는 둘 다 English로 맞추는 것을 권장합니다.

## 0. 완료된 리뷰 하나 먼저 만들기

최종 촬영에서는 완료된 리뷰의 Timeline과 Export 화면을 보여줘야 합니다. 새 설치라서 리뷰 목록이 비어 있다면 먼저 20–30초짜리 seed 영상을 만드세요.

1. iPhone 화면 녹화의 마이크를 켭니다.
2. 개인정보가 없는 화면을 천천히 이동합니다.
3. 아래 세 문장을 2초 정도 쉬어가며 말합니다.
   - `This is a test recording.`
   - `I am checking the ReviewTrace home screen.`
   - `The import buttons are easy to find.`
4. ReviewTrace 홈에서 **Language Spoken in This Review → English (en-US)**를 선택합니다.
5. 영상을 가져오고 상태가 **Ready**가 될 때까지 기다립니다.

이 완료 리뷰는 최종 영상의 촬영 대상일 뿐이며, 최종 수정 요청 자체는 아닙니다.

## 1. 최종 촬영 전 설정

1. ReviewTrace **Settings → App Language → English**를 선택합니다.
2. Home에서 **Language Spoken in This Review → English (en-US)**를 선택합니다.
3. 방해금지를 켜고 개인정보가 보이는 화면을 닫습니다.
4. 제어 센터에서 화면 녹화를 길게 누르고 **Microphone On**을 확인합니다.
5. 화면 녹화를 시작합니다.

## 2. 첫 번째 요청을 말할 화면

이동 순서:

`ReviewTrace → 아래 Reviews → 완료된 리뷰 선택 → 위 Timeline → 안쪽 Readable`

왼쪽에 세로형 미리보기 이미지가 보이는 전사 행까지 살짝 스크롤한 뒤 멈춥니다. 그 화면을 유지하면서 말합니다.

- 한국어 뜻: 여기는 읽기용 타임라인입니다. 왼쪽 미리보기 이미지를 조금 더 넓게 해주세요.
- 영어: `This is the readable timeline. Please make the preview image on the left a little wider.`
- 발음: `디스 이즈 더 리더블 타임라인. 플리즈 메이크 더 프리뷰 이미지 온 더 레프트 어 리틀 와이더.`

## 3. 두 번째 요청을 말할 화면

같은 완료 리뷰에서 이동합니다.

`위 Export → Direct Review Handoff 제목과 바로 아래 설명이 함께 보이는 위치`

카드가 화면에 또렷하게 보일 때 멈춘 뒤 말합니다.

- 한국어 뜻: 여기는 내보내기 화면입니다. Direct Review Handoff 아래 설명을 더 짧게 해주세요.
- 영어: `This is the Export screen. Please shorten the description under Direct Review Handoff.`
- 발음: `디스 이즈 디 익스포트 스크린. 플리즈 쇼튼 더 디스크립션 언더 다이렉트 리뷰 핸드오프.`

마지막으로 같은 화면에서 다음 한 문장을 말합니다.

- 한국어 뜻: 그 외에는 모두 그대로 유지해 주세요.
- 영어: `Please keep everything else unchanged.`
- 발음: `플리즈 킵 에브리씽 엘스 언체인지드.`

그 뒤 화면 녹화를 종료합니다.

## 4. 방금 찍은 최종 영상을 ReviewTrace로 처리하기

1. ReviewTrace Home으로 돌아옵니다.
2. **English (en-US)**가 선택되어 있는지 다시 확인합니다.
3. **Import Screen Recording**을 누르고 방금 찍은 최종 영상을 선택합니다.
4. 처리 중 제목에 English 전사가 표시되는지 확인합니다.
5. 완료 후 **Timeline → Readable**에서 두 요청 문장과 타임스탬프를 확인합니다.
6. **Export → Share Review with Codex**로 녹화, `full-transcript.md`, `codex-prompt.md`를 전달합니다.
7. Codex가 두 요청만 구현한 뒤 같은 두 화면을 다시 촬영해 before/after를 남깁니다.

## 실제 수정은 전사 패키지를 받은 뒤

- Timeline 미리보기: `72pt`에서 약 `84pt`로 변경할 예정입니다.
- Direct Review Handoff 설명: 의미는 유지하면서 더 짧게 바꿀 예정입니다.
- 위 두 항목 외 기존 기능과 화면은 유지합니다.
