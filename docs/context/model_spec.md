# cctv-helper Model Specification (도메인 모델 정의서) — 초안

> AI 에이전트용 개발 하네스 문서 중 하나입니다. 모델 수정 전 반드시 본 문서를 읽으십시오.
> 상위 지침: `AGENTS.md`. 관련: `docs/architecture/architecture_spec.md`, `docs/conventions/convention.md`.
> 본 문서의 모델은 초안이며 필드 확정 전입니다. 미확정 항목은 "미확정(초안)"으로 표기합니다.

## 1. 개요

`cctv-helper`의 도메인 모델은 로컬 문서와 1:1로 매핑되는
`fromMap` / `toMap` / `copyWith` 삼중 구조를 따릅니다 (`malssi` 패턴 계승).
모든 모델은 불변(immutable)이며 `final` 필드 + `const` 생성자를 사용합니다.

## 2. 저장 키 상수 (초안, 미확정)

`lib/core/constants/store_keys.dart`에 정의된 상수를 **반드시** 사용하십시오.
문자열 하드코딩 금지.

```dart
class StoreKeys {
  static const sources = 'sources';
  static const offsets = 'offsets';
  static const events = 'events';
  static const settings = 'settings';
}
```

## 3. 직렬화 공통 규칙

1. `fromMap(Map<String, dynamic> map)` — 저장 문서 → 객체.
   누락 필드는 `??` 기본값으로 방어 (`''`, `0`, `false`).
2. `toMap()` — 객체 → 저장 문서 Map. 키는 필드명과 동일.
3. `copyWith({...})` — 불변 업데이트. `null`이면 기존 값 유지.
4. 시간 변환 규칙 (전 모델 공통, 초안):
   ```dart
   // 오프셋은 ms 정수, 보정시각 = 표시시각 + 오프셋
   correctedAt = displayedAt.add(Duration(milliseconds: offsetMillis));
   ```
   `toMap()`에서는 `DateTime`을 ISO8601 문자열(UTC)로 저장하고,
   `fromMap()`에서는 `DateTime.tryParse() ?? DateTime.now()` 방어 읽기를 합니다.

## 4. 모델별 스펙 (초안)

### 4.1 `CctvSource` — 영상 원천 (초안)

- **위치**: `lib/features/sources/domain/cctv_source.dart` (예정)
- **성격**: 조사 대상 CCTV 영상 1개의 메타 정보.

| 필드 | 타입 | 설명 | 상태 |
|------|------|------|------|
| `id` | `String` | 원천 ID (예: 날짜키·파일명 기반) | 초안 |
| `label` | `String` | 표시명 (예: "편의점 입구") | 초안 |
| `fileName` | `String` | 원본 파일명 (바이너리 저장 안 함) | 초안 |
| `displayedAt` | `DateTime` | 영상 내 표시 시각 (기준 샘플) | 초안 |
| `createdAt` | `DateTime` | 등록 시각 | 초안 |

### 4.2 `TimeOffset` — 오프셋 (초안)

- **위치**: `lib/features/timeline/domain/time_offset.dart` (예정)
- **성격**: 기준 영상 대비 각 원천의 시간 차이.

| 필드 | 타입 | 설명 | 상태 |
|------|------|------|------|
| `sourceId` | `String` | 대상 원천 ID | 초안 |
| `offsetMillis` | `int` | 오프셋 (±ms, +면 영상 시계가 느림) | 초안 |
| `basis` | `String` | 측정 근거 메모 (예: "동일 차량 통과 장면") | 초안 |
| `createdAt` | `DateTime` | 측정 시각 | 초안 |

### 4.3 `SyncPoint` — 동기 기준점 (초안)

- **위치**: `lib/features/timeline/domain/sync_point.dart` (예정)
- **성격**: 오프셋 계산의 기준이 되는 공통 장면.

| 필드 | 타입 | 설명 | 상태 |
|------|------|------|------|
| `id` | `String` | 기준점 ID | 초안 |
| `referenceSourceId` | `String` | 기준 영상 ID | 초안 |
| `referenceAt` | `DateTime` | 기준 영상의 표시 시각 | 초안 |
| `note` | `String` | 설명 | 초안 |

### 4.4 `TimelineEvent` — 타임라인 사건 (초안)

- **위치**: `lib/features/events/domain/timeline_event.dart` (예정)
- **성격**: 보정 시각 기준의 사건 메모 1건.

| 필드 | 타입 | 설명 | 상태 |
|------|------|------|------|
| `id` | `String` | 사건 ID | 초안 |
| `sourceId` | `String` | 목격 원천 ID | 초안 |
| `displayedAt` | `DateTime` | 영상 내 표시 시각 | 초안 |
| `correctedAt` | `DateTime` | 보정 시각 (표시 + 오프셋) | 초안 |
| `memo` | `String` | 메모 (1줄) | 초안 |
| `createdAt` | `DateTime` | 작성 시각 | 초안 |

### 4.5 `AppSettings` — 설정 (초안)

- **위치**: `lib/features/settings/domain/app_settings.dart` (예정)

| 필드 | 타입 | 설명 | 상태 |
|------|------|------|------|
| `themeMode` | `String` | 라이트/다크/시스템 | 초안 |
| `defaultOffsetUnit` | `String` | ms/s 단위 기본값 | 초안 |
| `createdAt` | `DateTime` | 생성 시각 | 초안 |
