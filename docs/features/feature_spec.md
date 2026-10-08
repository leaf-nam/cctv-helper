# cctv-helper Feature Specification (주요 기능 명세서)

> AI 에이전트용 개발 하네스 문서 중 하나입니다. 상위 지침: `AGENTS.md`.
> 관련: `docs/context/model_spec.md` (모델), `docs/architecture/architecture_spec.md` (구조).
> 각 항목의 **구현 상태**는 기준 시점의 실제 코드를 기준으로 표기합니다.
> 미구현 부분은 "미구현"으로 명시합니다 (추측 금지).

## 1. CCTV 현재시간 입력 (#1, 1.0.0 구현됨)

- **요구**: CCTV 영상에 표시된 시각과 실제 현재시간을 쌍으로 입력한다.
- **구현 상태**: 구현됨.
- **관련 코드**:
  - 모델: `CctvSource.displayedAt`/`actualAt` (`model_spec.md` §4.2 참조).
  - 저장소: `CctvSourceRepository` (`lib/features/sources/data/`).
  - 화면: `CctvCard`의 시각 행 2개 (위 실제 / 아래 CCTV, `Divider` 분리) +
    `showTimeEditSheet()` ([지금] + ±1시간/10분/1분 스테퍼 + 직접 선택, live-apply).
  - CCTV 추가 시 실제 시각은 현재시간으로 자동 초기화.
  - 입력: `pickDateTime()` (날짜+시간 피커, `lib/core/widgets/datetime_field.dart`).

## 2. 오차 계산 (#2, 1.0.0 구현됨)

- **요구**: CCTV 표시시각과 실제시각의 오차(±ms)를 자동 계산한다.
  보정시각 = 표시시각 + 오프셋. 시간 표시는 보정+원본+오프셋 3요소 병기.
- **구현 상태**: 구현됨.
- **관련 코드**:
  - 서비스: `TimeCalcService` (`lib/core/services/time_calc_service.dart`).
  - 표시: `CctvCard`의 `오차:` 텍스트 (`formatOffset`).
- **향후 과제**: 초 단위 이하(ms) 입력 UI.

## 3. CCTV 이벤트 입력 (#3, 1.0.0 구현됨)

- **요구**: CCTV에서 나온 기록(메모, 사진 경로)을 입력한다.
  보정시각은 생성 시 오프셋으로 자동 확정한다.
- **구현 상태**: 구현됨.
- **관련 코드**:
  - 모델: `TimelineEvent` (`model_spec.md` §4.3 참조).
  - 저장소: `TimelineEventRepository` (사건별 보정시각 정렬).
  - 화면: `showEventSheet()` (`lib/features/sources/presentation/event_sheet.dart`).
- **향후 과제**: 사진 촬영·첨부 (`image_picker` 도입 검토).

## 4. 사건별 CCTV 관리 (#4, 1.0.0 구현됨)

- **요구**: 사건별로 CCTV를 추가·관리한다. 이름 변경·순서 변경 가능.
- **구현 상태**: 구현됨.
- **관련 코드**:
  - 모델: `CaseFile` + `CctvSource.sortOrder`.
  - 화면: `CasesScreen` (`/`), `CaseDetailScreen` (`/case/:id`,
    `ReorderableListView` + `onReorderItem`).
  - 상태: `CasesProvider`, `SourcesProvider`.

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

## 8. 기능-코드 매핑표

| # | 기능 | 저장 키 | 모델 | Repository | 화면/Provider | 상태 |
|---|------|--------|------|------------|---------------|------|
| 1 | 현재시간 입력 | `sources` | `CctvSource` | `CctvSourceRepository` | `CctvCard`, `SourcesProvider` | 구현됨 |
| 2 | 오차 계산 | — | — | — | `TimeCalcService` | 구현됨 |
| 3 | 이벤트 입력 | `events` | `TimelineEvent` | `TimelineEventRepository` | `event_sheet`, `EventsProvider` | 구현됨 |
| 4 | 사건별 CCTV 관리 | `cases`+`sources` | `CaseFile` | `CaseRepository` | `CasesScreen`·`CaseDetailScreen` | 구현됨 |
| 5 | 검색 | — | — | — | — | 미구현 |
| 6 | 지도 | — | — | — | — | 미구현 |
| 7 | 그래프·타임라인 | — | — | — | — | 미구현 |
