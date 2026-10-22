# cctv-helper Feature Specification (주요 기능 명세서)

> AI 에이전트용 개발 하네스 문서 중 하나입니다. 상위 지침: `AGENTS.md`.
> 관련: `docs/context/model_spec.md` (모델), `docs/architecture/architecture_spec.md` (구조).
> 각 항목의 **구현 상태**는 기준 시점의 실제 코드를 기준으로 표기합니다.
> 미구현 부분은 "미구현"으로 명시합니다 (추측 금지).

## 1. CCTV 현재시간 입력 (#1, 1.0.0 / UX 개선 1.0.1 구현됨)

- **요구**: CCTV 영상에 표시된 시각과 실제 현재시간을 쌍으로 입력한다.
- **구현 상태**: 구현됨.
- **관련 코드**:
  - 모델: `CctvSource.displayedAt`/`actualAt` (`model_spec.md` §4.2 참조).
  - 저장소: `CctvSourceRepository` (`lib/features/sources/data/`).
  - 화면: `CctvCard`의 시각 행 2개 (위 실제 / 아래 CCTV, `Divider` 분리) +
    `showTimeEditSheet()` ([지금] + ±1일/1시간/10분/1분/10초/1초 스테퍼 + 직접 선택).
  - CCTV 추가 시 실제 시각은 현재시간으로 자동 초기화.
  - 입력: `pickDateTime()` (연도·월 선택 → 일 선택 → 시·분 선택,
    `lib/core/widgets/datetime_field.dart`).
- **1.0.1 UX 개선**:
  - 시각 표시를 `날짜(yyyy-MM-dd)` / `시간(HH:mm:ss)` **2줄**로 분리하고 초를 항상 표시.
  - 좁은 화면(320dp)에서는 `입력`/`지금` 버튼을 아이콘으로 축약해 잘림 방지.
  - 시각 입력 시트는 **draft 편집 + 적용/닫기**로 분리. 닫기 시 변경 사항은 저장하지 않음.
  - 스테퍼 버튼을 길게 누르면 400ms 후 90ms 간격으로 연속 증감.
  - 날짜 직접입력 파서가 `yyyy-MM-dd`, `yyyy.MM.dd`, `yyyy/MM/dd`, `yyyyMMdd`,
    `yyyy년 MM월 dd일`을 지원하고 2월 30일 등 존재하지 않는 날짜를 거부.
  - `flutter_localizations` + `ko` 로케일로 날짜 선택기 입력 형식·라벨을 한국어화.
  - 연도 선택 단계에서 12개월 그리드를 함께 보여 줘 월 이동을 바로 선택.
  - 바텀시트 `useSafeArea`와 키보드 인셋으로 Android 내비게이션 바/홈 인디케이터 겹침 방지.

## 2. 오차 계산 (#2, 1.0.0 구현됨)

- **요구**: CCTV 표시시각과 실제시각의 오차(±ms)를 자동 계산한다.
  보정시각 = 표시시각 + 오프셋. 시간 표시는 보정+원본+오프셋 3요소 병기.
- **구현 상태**: 구현됨.
- **관련 코드**:
  - 서비스: `TimeCalcService` (`lib/core/services/time_calc_service.dart`).
  - 표시: `CctvCard`의 오차 문장 (`formatOffset` — `CCTV가 2분 느림 (+120000ms)` 형태).
- **향후 과제**: 초 단위 이하(ms) 입력 UI.

## 3. CCTV 이벤트 입력 (#3, 1.0.0 구현됨)

- **요구**: CCTV에서 나온 기록(메모, 사진 경로)을 입력한다.
  보정시각은 생성 시 오프셋으로 자동 확정한다.
- **구현 상태**: 구현됨.
- **관련 코드**:
  - 모델: `TimelineEvent` (`model_spec.md` §4.3 참조, `photoPath`에 촬영/선택 사진 저장).
  - 저장소: `TimelineEventRepository` (사건별 보정시각 정렬).
  - 화면: `showEventSheet()` (카메라 촬영·앨범 선택 + 썸네일 미리보기, `image_picker`).
    영상 시각은 날짜/시간 2줄로 표시하고, 시각 입력 시트는 적용/닫기로 확정한다.
- **향후 과제**: 사진 원본 보관 위치·동기화 정책.

## 4. 사건별 CCTV 관리 (#4, 1.0.0 구현됨)

- **요구**: 사건별로 CCTV를 추가·관리한다. 이름 변경·순서 변경 가능.
  사건 목록도 순서 변경·등록일자 표시·지우기 버튼 제공. 모두 로컬 저장.
- **구현 상태**: 구현됨.
- **관련 코드**:
  - 모델: `CaseFile` + `CctvSource.sortOrder` (+`CaseFile.sortOrder`).
  - 화면: `CasesScreen` (`/`), `CaseDetailScreen` (`/case/:id`,
    `ReorderableListView` + `onReorderItem`).
  - 상태: `CasesProvider`, `SourcesProvider`.
  - 저장: `LocalStore` (`SharedPreferences` + JSON, 변경마다 저장·시작 시 복원).

## 5. 사건별 검색 (#5, 미구현)

- **요구**: 사건별 검색 기능 (제목, 내용 기준).
- **구현 상태**: 미구현.
- **향후 과제**: `CasesScreen` 검색창 + 이벤트 메모 포함 여부.

## 6. 지도 위치 표시 (#6, 미구현)

- **요구**: 여러 CCTV의 위치를 지도에 표시.
- **구현 상태**: 미구현.
- **향후 과제**: 지도 패키지 선정 (아키텍처 이슈로 분리).

## 7. 그래프·타임라인 표시 (#7, 미구현)

- **요구**: 전체 이벤트를 보정시각 기준으로 그래프·타임라인 표시.
- **구현 상태**: 미구현 (사건별 보정시각 정렬 조회는 #3에서 선행 구현됨).
- **향후 과제**: 차트 패키지 선정, 사건 단위 통합 타임라인 화면.

## 8. 첫 실행 튜토리얼 (#25, 1.0.1 구현됨)

- **요구**: 첫 실행 시 앱 사용 흐름을 4단계로 안내하고, 다시 보기 진입점을 제공한다.
- **구현 상태**: 구현됨.
- **동작**:
  - 첫 실행(`tutorialSeen=false`)이면 사건 목록 진입 후 `/onboarding`으로 이동.
  - ① 사건 만들기 ② 실제시간/CCTV 시간 입력 ③ 오차 확인 ④ 기록·타임라인.
  - `다음`/`이전`/`건너뛰기`/`시작하기`, 페이지 인디케이터.
  - `건너뛰기` 또는 마지막 `시작하기`에서 `tutorialSeen=true` 저장.
  - 사건 목록 앱바의 도움말 버튼으로 `튜토리얼 다시 보기`.
- **관련 코드**:
  - `lib/features/onboarding/providers/tutorial_provider.dart`
  - `lib/features/onboarding/presentation/tutorial_screen.dart`
  - `lib/routing/app_router.dart` (`/onboarding`)
  - `lib/core/constants/store_keys.dart` (`tutorialSeen`)

## 9. 기능-코드 매핑표

| # | 기능 | 저장 키 | 모델 | Repository | 화면/Provider | 상태 |
|---|------|--------|------|------------|---------------|------|
| 1 | 현재시간 입력 | `sources` | `CctvSource` | `CctvSourceRepository` | `CctvCard`, `SourcesProvider` | 구현됨 |
| 2 | 오차 계산 | — | — | — | `TimeCalcService` | 구현됨 |
| 3 | 이벤트 입력 | `events` | `TimelineEvent` | `TimelineEventRepository` | `event_sheet`, `EventsProvider` | 구현됨 |
| 4 | 사건별 CCTV 관리 | `cases`+`sources` | `CaseFile` | `CaseRepository` | `CasesScreen`·`CaseDetailScreen` | 구현됨 |
| 5 | 검색 | — | — | — | — | 미구현 (v1.2.0 예정) |
| 6 | 지도 | — | — | — | — | 미구현 (v1.2.0 예정) |
| 7 | 그래프·타임라인 | `events` | `TimelineEvent` | `TimelineEventRepository` | — | 미구현 (v1.1.0 예정) |
| 8 | 첫 실행 튜토리얼 | `tutorialSeen` | — | — | `TutorialScreen`, `TutorialProvider` | 구현됨 |
