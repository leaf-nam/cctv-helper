# cctv-helper Architecture Specification (시스템 아키텍처 스펙) — 초안

> AI 에이전트용 개발 하네스 문서 중 하나입니다. 코드 수정 전 반드시 본 문서를 읽으십시오.
> 상위 지침: `AGENTS.md`. 관련: `docs/context/model_spec.md`, `docs/conventions/convention.md`.
> 본 문서는 `malssi`의 `architecture_spec.md` 패턴(현재 구조 분석 + 다이어그램 +
> 확장 계획)을 Flutter 스택에 맞게 적용한 초안입니다.
> 확정되지 않은 항목은 "미확정(초안)"으로 표기합니다 (추측 금지).

## 1. 시스템 아키텍처 (초안)

`cctv-helper`는 Flutter 기반 CCTV 시간 동기화 도우미 앱입니다.
`malssi`와 동일한 feature-based 디렉토리 구조를 사용합니다.

- **진입점 (1.0.0 확정)**: `lib/main.dart`의 `main()`이 `AppShell` 실행.
- **앱 셸 (1.0.0 확정)**: `lib/app.dart`의 `AppShell`(`StatelessWidget`)이 `MultiProvider`
  (`CasesProvider` + `SourcesProvider` + `EventsProvider`)로 감싼
  `MaterialApp.router`를 제공합니다.
- **라우팅 (1.0.0 확정)**: `lib/routing/app_router.dart`의 `appRouter`(`GoRouter`, `initialLocation: '/'`).
  라우트: `/` (`CasesScreen`, 사건 목록), `/case/:id` (`CaseDetailScreen`, CCTV 관리).
  `/sources`·`/events`·`/settings` 분리 라우트는 폐기 — CCTV·기록은 사건 상세 내 카드로 통합.
- **상태 관리**: `provider` + `ChangeNotifier` + `context.watch`/`context.read` 단일 패턴
  (`malssi`와 동일. `riverpod` 도입 금지).
- **데이터 계층 (초안)**: feature별 `*_repository.dart` 추상 클래스 + `InMemory*` 구현체.
- **저장 계층 (초안, 미확정)**: 로컬 저장(`SharedPreferences` + JSON) 우선 검토.
  영상 바이너리는 저장하지 않고 메타·오프셋·메모만 저장합니다.
  원격 백엔드 사용 계획 없음 (미확정).
- **공용 서비스 (초안)**: `TimeCalcService` (오프셋→보정시각 계산),
  `ExportService` (CSV/텍스트 내보내기), `LocalStore` (JSON 지속화) 후보.

```
┌──────────────────────────────────────────────────────────────┐
│                    Flutter App (UI + Routing)                │
│   main.dart (MyApp) → app.dart (AppShell: MultiProvider)     │
│   routing/app_router.dart (GoRouter)                         │
│   ┌────────────┐ ┌─────────────┐ ┌────────────────────────┐  │
│   │ Timeline   │ │ Sources     │ │ Events / Settings      │  │
│   │ (동기)     │ │ (원천)      │ │ (메모 / 설정)          │  │
│   └─────┬──────┘ └──────┬──────┘ └───────────┬────────────┘  │
└─────────┼───────────────┼────────────────────┼───────────────┘
          ▼               ▼                    ▼
┌─────────┴───────────────┴────────────────────┴───────────────┐
│              Feature Modules (features/<feature>/)           │
│   timeline (TimelineRepository/Provider)                     │
│   sources (CctvSourceRepository/Provider)                    │
│   events (TimelineEventRepository/Provider)                 │
│   settings (SettingsRepository/Provider)                    │
├──────────────────────────────────────────────────────────────┤
│  Core: constants  services(TimeCalcService, ExportService,  │
│    LocalStore)  theme(AppTheme)  widgets(공용 위젯)          │
│  Storage: 로컬 (SharedPreferences + JSON, 초안)             │
└──────────────────────────────────────────────────────────────┘
```

### 1.2 디렉토리 규칙

```
lib/
  main.dart                # 진입점 (MyApp)
  app.dart                 # AppShell (MultiProvider + MaterialApp.router)
  routing/app_router.dart  # GoRoute 등록 (신규 화면은 여기에 추가)
  core/
    constants/             # StoreKeys 등 공용 상수
    services/              # TimeCalcService (오프셋→보정시각 계산)
    theme/                 # AppTheme (미도입, 1.0.0 이후)
    widgets/               # datetime_field 등 공용 위젯
  features/
    <feature>/
      data/                # Repository 추상/구현
      domain/              # 도메인 모델
      presentation/        # Screen/Widget
      providers/           # 상태 관리
```

- 새 기능은 `features/<feature>/{data,domain,presentation,providers}` 4계층으로 추가합니다.
  1.0.0 feature명: `cases`, `sources`, `events`.
- 공용 코드는 `core/{constants,services,theme,widgets}`에 둡니다.
- 라우트는 `lib/routing/app_router.dart`의 `GoRoute`에 등록합니다.

### 1.3 의존성 관리 (`pubspec.yaml`, 초안)

| 패키지 | 버전 | 용도 | 비고 |
|--------|------|------|------|
| `flutter` | SDK | 프레임워크 | `uses-material-design: true` |
| `provider` | `^6.0.0` | 상태 관리 (주) | `AppShell` MultiProvider, 화면 watch/read |
| `go_router` | `^13.2.0` | 라우팅 | `appRouter` |
| `shared_preferences` | `^2.5.5` | 로컬 지속화 | `LocalStore` 후보 |
| `image_picker` | `^1.2.4` | 사진 촬영·앨범 선택 | 기록 시트 첨부 (#3) |
| `csv` | 미확정 | 내보내기 | 도입 여부 이슈로 분리 |
| `share_plus` | 미확정 | 내보내기 공유 | 도입 여부 이슈로 분리 |
| `flutter_test` (`dev`) | SDK | 테스트 | `flutter test` |
| `flutter_lints` | — | 린트 | `analysis_options.yaml`에서 include |

신규 의존성 추가 시 `flutter pub get` 실행 후 `pubspec.lock` 변경분을 함께 커밋합니다.

## 2. 외부 연동 규격 (초안)

### 2.1 로컬 저장소 키 규격 (미확정)

- 키명은 상수 경유 (문자열 리터럴 금지). 상수 파일 위치는 `lib/core/constants/` (초안).
- 문서 스키마: `model_spec.md` §4의 모델별 필드표 준수.

### 2.2 시간 계산 (`TimeCalcService`, 초안)

- 입력: 영상 내 표시 시각 + 오프셋 ms (`TimeOffset`).
- 출력: 보정 시각 (기준 영상 타임라인에 맞춘 절대 시각).
- 경계 조건(음수 오프셋, 자정跨越, DST 등)은 모델 스펙 확정 후 본 문서에 추가합니다.

### 2.3 내보내기 (`ExportService`, 초안)

- 형식: CSV/텍스트 후보 (미확정).
- 포함 필드: 보정시각, 원천 ID, 원본시각, 오프셋, 메모 (초안).

## 3. 확장 계획 (초안)

1. **모델 확정**: `CctvSource`/`TimeOffset`/`SyncPoint`/`TimelineEvent` 필드 확정.
2. **타임라인 MVP**: 영상 등록 → 오프셋 입력 → 보정 타임라인 정렬.
3. **메모·내보내기**: 사건 메모 + CSV/텍스트 출력.
4. **정밀 측정 지원**: 동일 장면 두 영상 대조 UI 등 (미확정, 후속 이슈).
5. **테스트 보강**: 신규 기능 추가 시 회귀 테스트 함께 작성.
