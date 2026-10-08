# cctv-helper Feature Specification (주요 기능 명세서) — 초안

> AI 에이전트용 개발 하네스 문서 중 하나입니다. 상위 지침: `AGENTS.md`.
> 관련: `docs/context/model_spec.md` (모델), `docs/architecture/architecture_spec.md` (구조).
> 본 문서는 초안이며 각 항목의 **구현 상태**는 실제 코드를 기준으로 표기합니다.
> 미구현 부분은 "미구현"으로 명시합니다 (추측 금지).

## 1. 영상 원천 등록 (`/sources`, 미구현)

- **요구 (초안)**: 조사 대상 CCTV 영상을 등록한다. 저장하는 것은 바이너리가 아니라
  메타(표시명·파일명·영상 내 표시 시각 샘플)이다.
- **구현 상태**: 미구현.
- **관련 코드 (예정)**:
  - 모델: `CctvSource` (`model_spec.md` §4.1 참조).
  - 저장소: `CctvSourceRepository` (`lib/features/sources/data/`).
  - 화면: `SourcesScreen` (`lib/features/sources/presentation/sources_screen.dart`).
  - 상태: `SourcesProvider` (`lib/features/sources/providers/`).
- **향후 과제**: 파일 피커 연동 여부, 표시 시각 입력 UX.

## 2. 오프셋 측정·동기 타임라인 (`/`, 미구현)

- **요구 (초안)**: 기준 영상을 정하고 각 영상의 오프셋(±ms)을 입력·계산한다.
  보정 시각(표시 + 오프셋) 기준으로 모든 장면을 하나의 타임라인에 정렬한다.
- **구현 상태**: 미구현.
- **관련 코드 (예정)**:
  - 모델: `TimeOffset`, `SyncPoint` (`model_spec.md` §4.2·§4.3 참조).
  - 서비스: `TimeCalcService` (`lib/core/services/`).
  - 화면: `TimelineScreen` (`lib/features/timeline/presentation/`).
- **향후 과제**: 동일 장면 대조 UI, 오프셋 자동 추정 여부.

## 3. 사건 메모 (`/events`, 미구현)

- **요구 (초안)**: 보정 시각 기준으로 사건 메모를 남긴다.
  원천·표시시각·보정시각·메모를 1건으로 기록한다.
- **구현 상태**: 미구현.
- **관련 코드 (예정)**:
  - 모델: `TimelineEvent` (`model_spec.md` §4.4 참조).
  - 화면: `EventsScreen` (`lib/features/events/presentation/`).

## 4. 내보내기 (미구현)

- **요구 (초안)**: 동기 타임라인 + 메모를 CSV/텍스트로 내보낸다.
- **구현 상태**: 미구현.
- **관련 코드 (예정)**: `ExportService` (`lib/core/services/`).

## 5. 설정 (`/settings`, 미구현)

- **요구 (초안)**: 화면 모드(라이트/다크/시스템), 오프셋 기본 단위 등을 설정한다.
- **구현 상태**: 미구현.
- **관련 코드 (예정)**:
  - 모델: `AppSettings` (`model_spec.md` §4.5 참조).
  - 화면: `SettingsScreen`.

## 6. 기능-코드 매핑표 (초안)

| # | 기능 | 저장 키 | 모델 | Repository | 화면/Provider | 상태 |
|---|------|--------|------|------------|---------------|------|
| 1 | 영상 원천 등록 | `sources` | `CctvSource` | `CctvSourceRepository` | `SourcesScreen`, `SourcesProvider` | 미구현 |
| 2 | 동기 타임라인 | `offsets` | `TimeOffset` / `SyncPoint` | `TimelineRepository` | `TimelineScreen`, `TimelineProvider` | 미구현 |
| 3 | 사건 메모 | `events` | `TimelineEvent` | `TimelineEventRepository` | `EventsScreen`, `EventsProvider` | 미구현 |
| 4 | 내보내기 | — | — | — | `ExportService` | 미구현 |
| 5 | 설정 | `settings` | `AppSettings` | `SettingsRepository` | `SettingsScreen`, `SettingsProvider` | 미구현 |
