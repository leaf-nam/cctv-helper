# cctv-helper Code Convention (코드 컨벤션) — 초안

> AI 에이전트용 개발 하네스 문서 중 하나입니다. 상위 지침: `AGENTS.md`.
> 관련: `docs/architecture/architecture_spec.md`, `docs/context/model_spec.md`.
> `analysis_options.yaml`에서 `package:flutter_lints/flutter.yaml`을 include합니다.
> 본 문서는 `malssi`의 `convention.md` 패턴을 계승합니다.

## 1. Dart/Flutter 스타일

- `flutter_lints` 권장 린트를 따릅니다. `flutter analyze` 통과를 필수로 합니다.
- 파일명은 `snake_case.dart`, 클래스명은 `UpperCamelCase`, 변수/함수는 `lowerCamelCase`,
  상수는 기존 코드 관례를 따릅니다.
- import 순서: `flutter` → 서드파티(`provider`, `go_router` 등) → `package:cctv_helper/...`.
- 위젯 생성자는 `const` 가능하면 `const`로 선언하고 `super.key`를 받습니다.

## 2. 네이밍 컨벤션

- Screen: `<Name>Screen` (예: `TimelineScreen`, `SourcesScreen`, `EventsScreen`, `SettingsScreen`).
- Repository: `<Name>Repository` 추상 클래스 + `InMemory<Name>Repository` 구현체
  (예: `TimelineRepository` / `InMemoryTimelineRepository`).
- Provider/Notifier: `<Name>Provider` (예: `TimelineProvider`).
- 모델: `CctvSource`, `TimeOffset`, `SyncPoint`, `TimelineEvent`, `AppSettings`.
- 저장 키: 상수 경유 (문자열 리터럴 금지).

## 3. 상태 관리

- `provider` + `ChangeNotifier` + `context.watch`/`context.read` 단일 패턴을 쓴다
  (`AppShell`의 `MultiProvider`, 각 Provider·화면).
- `riverpod`는 신규 코드에서 사용하지 마십시오 (도입 필요시 아키텍처 이슈로 분리).

## 4. 테마 (초안)

- 조사용 앱이므로 가독성 우선 (밝은 배경·고대비 텍스트).
- 화면 코드는 `Theme.of(context)`를 쓰고, 색상 하드코딩을 피합니다.
- 말씨식 탭별 고정 다크 같은 예외 규칙은 없음 (필요시 본 문서 개정).

## 5. 에러/로딩 처리 패턴

- `AsyncValue` 계열은 `.when(data:, loading:, error:)` 삼분기로 처리합니다.
  - 로딩: `const CircularProgressIndicator()`.
  - 에러: `Text('Error: $err')`.
  - 빈 데이터: 안내 문구 (예: `'등록된 영상이 없습니다.'`).
- 비동기 콜백 후 `context` 사용 전 `if (!context.mounted) return;` 가드를 둡니다.

## 6. 라우팅

- 신규 화면은 `lib/routing/app_router.dart`에 등록합니다.
- 경로 파라미터는 `state.pathParameters['id'] ?? ''` 패턴으로 안전하게 읽습니다.
- 화면 이동은 `context.go(...)`를 사용합니다.

## 7. 시간 표시 (초안)

- 모든 시각 표시는 **보정시각 + 원본시각 + 오프셋** 3요소를 함께 보여주는 것을 원칙으로 합니다
  (예: `보정 14:02:11 (+영상 14:00:11, +120000ms)`).
  조사 기록의 추적 가능성을 위해서입니다.
- ms 단위 오프셋 입력은 부호(±) 실수를 막기 위해 확인 문구를 둡니다.

## 8. 디버그 전용 코드 (운영 유출 금지)

- 디버그 UI는 `kDebugMode` 게이트 안에서만 그립니다.
- `debug` 접두사 메서드는 릴리즈 UI에서 호출하지 마십시오.
