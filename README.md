# Peak 🚴

> 날씨 보고 라이딩 잡는 앱, 초대는 문자 한 통

로드바이커를 위한 날씨 기반 라이딩 일정 소셜 앱. Flutter MVP.

---

## 기능

- **2주 날씨 캘린더** — 날짜별 라이딩 점수(0~100) 한눈에 확인
- **오늘의 라이딩 추천** — 날씨 상태·추천 시간대·이유 자동 요약
- **일정 등록** — 날씨 상세 탭 → 혼자/같이 선택 → 30초 이내 등록
- **그룹 초대** — 시스템 공유 시트(문자·카카오톡)로 링크 한 번에 발송
- **날씨 변동 알림** — 강수확률 급등 시 FCM 푸시 + 대안 날짜 제안
- **AdMob 앱 오픈 광고** — ATT 권한 요청 포함

## 기술 스택

| 영역 | 사용 기술 |
|---|---|
| 프레임워크 | Flutter 3 / Dart |
| 상태 관리 | Riverpod 3 |
| 라우팅 | go_router |
| 백엔드 | Supabase (예정) · Firebase Messaging · Firebase Hosting |
| 날씨 API | KMA (기상청) + Supabase Edge Functions |
| 광고 | Google Mobile Ads (AdMob) |
| 공유 | share_plus |

## 시작하기

### 1. 의존성 설치

```bash
flutter pub get
```

### 2. Firebase 설정

실제 Firebase 프로젝트 설정 파일을 `.example` 파일을 참고해 생성한다.

```bash
cp lib/firebase_options.dart.example lib/firebase_options.dart
cp android/app/google-services.json.example android/app/google-services.json
cp ios/Runner/GoogleService-Info.plist.example ios/Runner/GoogleService-Info.plist
```

각 파일에서 `YOUR_*_API_KEY` 플레이스홀더를 실제 Firebase 프로젝트 값으로 교체.

### 3. 환경 변수

```bash
cp .env.example .env
```

`.env`에 Supabase URL·anon key 입력.

### 4. 실행

```bash
# iOS 시뮬레이터
flutter run -d <simulator_id>

# 웹 (광고·ATT 제외)
flutter run -d chrome
```

## 프로젝트 구조

```
lib/
├── core/
│   ├── providers/      # Riverpod 전역 providers
│   ├── router/         # go_router 라우팅
│   ├── services/       # AdMob, FCM, Supabase
│   └── theme/          # 앱 테마
├── features/
│   ├── home/           # 날씨 캘린더 + 일정
│   ├── group/          # 그룹 라이딩
│   ├── notifications/  # 알림 인박스
│   ├── settings/       # 설정
│   └── splash/         # 스플래시 + 광고
└── shared/
    ├── data/           # 공통 mock 데이터
    └── widgets/        # 공통 위젯 (InviteShareSheet 등)
```

## 기획 문서

- [`docs/blueprint.md`](docs/blueprint.md) — 프로덕트 블루프린트 (문제 정의, UVP, 비즈니스 모델)
- [`docs/userstory.md`](docs/userstory.md) — 유저 스토리 맵 (US-001~016, Acceptance Criteria)
- [`docs/ia.md`](docs/ia.md) — 정보 구조도 (탭 구조, 라우팅 경로)

## 개발 현황

현재 **프론트엔드 우선 개발** 단계. 모든 데이터는 mock으로 동작하며, Firestore/Supabase 연동은 다음 단계.
