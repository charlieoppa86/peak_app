# Peak — 개발 가이드

날씨 기반 라이딩 일정 소셜 앱 (로드바이커 대상). 비개발자 솔로 빌드, Flutter MVP.

## 기획 문서 (작업 전 필수 확인)

기능 구현, 화면 설계, 라우팅, 우선순위 판단 시 아래 문서를 먼저 확인하고 그 내용에 맞춰 작업한다:

- `docs/blueprint.md` — 프로덕트 블루프린트: 문제 정의, 타겟 고객, UVP, 비즈니스 모델, MVP 범위, 성공 지표, 리스키 어선션
- `docs/userstory.md` — 유저 스토리 맵: US-001~US-016 (Must/Should/Could/Won't), Acceptance Criteria, INVEST 체크
- `docs/ia.md` — 정보 구조도: 탭 구조, 화면 depth, 라우팅 경로(`lib/core/router/app_router.dart`와 1:1 대응), 커버리지 매트릭스

## 적용 원칙

- 새 화면/기능을 만들 때는 `docs/ia.md`의 라우팅 경로와 depth를 그대로 따른다 (임의 변경 금지, 변경 필요 시 문서도 함께 갱신)
- 구현 범위는 `docs/userstory.md`의 우선순위(Must → Should → Could)를 따르고, `Won't` 항목(Strava 연동, GPX 지도, 소셜 피드, Apple Watch)은 만들지 않는다
- Acceptance Criteria는 해당 기능의 완료 기준이므로 구현 후 AC와 대조해 검증한다
- 화면 디자인/UX 결정 시 `docs/blueprint.md`의 UVP("날씨 보고 라이딩 잡는 앱, 초대는 문자 한 통")와 핵심 가설을 기준으로 판단한다
- 문서와 코드가 어긋나면 먼저 사용자에게 확인한다 — 문서가 최신 의사결정을 반영하지 못했을 수 있음

## UI 작업 — Stitch MCP

이 프로젝트(로컬 스코프)에는 `stitch` MCP 서버가 연결되어 있다. 화면을 만들거나 수정할 때:

- 먼저 Stitch에서 해당 화면의 디자인을 조회해 레이아웃·컬러·타이포·간격을 확인하고, 그 디자인과 동일하게 구현한다 (임의로 다르게 디자인하지 않는다)
- 디자인이 `docs/blueprint.md` / `docs/ia.md`의 결정사항과 다르면 작업 전에 사용자에게 확인한다
- Stitch에 해당 화면 디자인이 없으면 진행 전에 사용자에게 알린다 (추측으로 만들지 않는다)

## 개발 순서 — 프론트 먼저, 목 데이터 사용

- 현재 단계는 프론트엔드 우선 개발이며, 백엔드(Firestore 등)는 이후에 연결한다
- 화면에 필요한 데이터(날씨 점수, 일정, 참석자, 알림 등)는 실제 API/DB 연동 없이 **mock data**로 채운다
- mock data는 화면별로 바로 식별 가능한 형태로 작성하고, 추후 실제 데이터 모델로 교체하기 쉽도록 화면 코드와 데이터 소스를 분리해 둔다 (예: repository/provider 계층을 mock 구현으로 먼저 채우고 인터페이스는 실제 구현으로 교체 가능하게)

## 알려진 이슈

- `~/Desktop` 경로가 iCloud Drive로 동기화되어 iOS/macOS 빌드 시 코드사인 오류(`resource fork... not allowed`)가 발생할 수 있음. 발생 시 web(`flutter run -d chrome`)으로 검증하거나 프로젝트를 iCloud 미동기화 폴더로 이동
