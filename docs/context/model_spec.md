# cctv-helper Model Specification (도메인 모델 정의서)

> AI 에이전트용 개발 하네스 문서 중 하나입니다. 모델 수정 전 반드시 본 문서를 읽으십시오.
> 상위 지침: `AGENTS.md`. 관련: `docs/architecture/architecture_spec.md`, `docs/conventions/convention.md`.
> 1.0.0 (#1~#4)에서 `CaseFile`/`CctvSource`/`TimelineEvent` 확정.
> 초안의 `TimeOffset`/`SyncPoint` 분리 모델은 폐기 — 오프셋은 `CctvSource` 내 계산값으로 통합.

## 1. 개요

`cctv-helper`의 도메인 모델은 로컬 문서와 1:1로 매핑되는
`fromMap` / `toMap` / `copyWith` 삼중 구조를 따릅니다 (`malssi` 패턴 계승).
모든 모델은 불변(immutable)이며 `final` 필드 + `const` 생성자를 사용합니다.

## 2. 저장 키 상수 (1.0.0 확정)

`lib/core/constants/store_keys.dart`에 정의된 상수를 **반드시** 사용하십시오.
문자열 하드코딩 금지.

```dart
class StoreKeys {
  static const cases = 'cases';
  static const sources = 'sources';
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

## 4. 모델별 스펙

### 4.1 `CaseFile` — 사건 (1.0.0 확정, #4)

- **위치**: `lib/features/cases/domain/case_file.dart`
- **성격**: 조사 사건 1건. CCTV·기록의 최상위 그룹.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | `String` | 사건 ID (microsecondsSinceEpoch) |
| `title` | `String` | 사건 제목 (필수, 빈 문자열 불가) |
| `description` | `String` | 설명 (1.0.0 UI 미입력, 예약) |
| `sortOrder` | `int` | 사건 목록 순서 (reorder) |
| `createdAt` | `DateTime` | 생성 시각 (등록일자 표시) |

### 4.2 `CctvSource` — 영상 원천 (1.0.0 확정, #1·#2·#4)

- **위치**: `lib/features/sources/domain/cctv_source.dart`
- **성격**: 사건에 속한 CCTV 1대. 오프셋은 별도 모델이 아니라 계산 getter.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | `String` | 원천 ID |
| `caseId` | `String` | 소속 사건 ID |
| `name` | `String` | CCTV 이름 (변경 가능, #4) |
| `sortOrder` | `int` | 사건 내 순서 (reorder, #4) |
| `displayedAt` | `DateTime?` | CCTV 표시시각 (미입력 허용, #1) |
| `actualAt` | `DateTime?` | 실제 현재시간 (미입력 허용, #1) |
| `createdAt` | `DateTime` | 등록 시각 |

- **계산**: `offsetMillis = actualAt - displayedAt` (ms, 둘 다 있을 때만.
  없으면 `null` → UI에 "미계산" 표시).
- **`copyWith` 주의**: `displayedAt`/`actualAt`은 nullable 필드이므로
  `DateTime? Function()?` 래퍼로 감싸 null 할당과 미변경을 구분한다.

### 4.3 `TimelineEvent` — 타임라인 사건 기록 (1.0.0 확정, #3)

- **위치**: `lib/features/events/domain/timeline_event.dart`
- **성격**: 보정 시각 기준의 사건 기록 1건 (메모 + 사진 경로).

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | `String` | 기록 ID |
| `caseId` | `String` | 소속 사건 ID |
| `sourceId` | `String` | 목격 CCTV ID |
| `displayedAt` | `DateTime` | 영상 내 표시 시각 |
| `correctedAt` | `DateTime` | 보정 시각 (생성 시 확정, 표시 + 오프셋) |
| `memo` | `String` | 기록 메모 |
| `photoPath` | `String` | 사진 파일 경로 (바이너리 저장 안 함, 없으면 `''`) |
| `createdAt` | `DateTime` | 작성 시각 |

### 4.5 `AppSettings` — 설정 (초안)

- **위치**: `lib/features/settings/domain/app_settings.dart` (예정)

| 필드 | 타입 | 설명 | 상태 |
|------|------|------|------|
| `themeMode` | `String` | 라이트/다크/시스템 | 초안 |
| `defaultOffsetUnit` | `String` | ms/s 단위 기본값 | 초안 |
| `createdAt` | `DateTime` | 생성 시각 | 초안 |
