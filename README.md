# cctv-helper — CCTV 조사 시간 동기화 도우미

여러 대의 CCTV 영상의 어긋난 시각을 맞춰 하나의 동기 타임라인으로 조사하는 Flutter 앱입니다.

## 문제 정의 (초안)

- 같은 사건을 찍은 CCTV라도 기기 시계가 어긋나 있어 영상 속 시각이 서로 다름
- 조사관이 각 영상의 오프셋(기준 대비 ±ms)을 수기로 메모·계산해야 함
- 동기된 타임라인 없이 장면을 오가며 확인하기 불편함

## 목표 (초안)

1. 영상 원천 등록 (파일 메타 + 영상 내 표시 시각)
2. 오프셋 측정 (기준 영상 대비 차이 입력·계산)
3. 동기 타임라인 (보정 시각 기준으로 정렬·재생 점프)
4. 사건 메모 + 내보내기 (CSV/텍스트)

상세는 `docs/features/feature_spec.md` 참조.

## 시작하기

```sh
flutter pub get
flutter analyze   # 0 issues 필수
flutter test      # 전체 통과 필수
flutter run -d macos   # 또는 -d chrome
```

## 프로젝트 구조 (초안, `malssi` 패턴 계승)

```
lib/
  main.dart / app.dart        # 진입점, AppShell(MultiProvider + router)
  routing/app_router.dart     # 라우트 등록
  core/{constants,services,theme,widgets}
  features/<feature>/{data,domain,presentation,providers}
test/                         # 단위·위젯 테스트
docs/                         # 아래 문서 인덱스 참조
tool/                         # 보조 스크립트
```

## 문서 (개발 하네스)

AI 에이전트 및 기여자는 코드 수정 전 아래 문서를 먼저 읽어주세요
(상위 지침: `AGENTS.md`). `malssi`의 하네스 체계를 계승합니다.

- `AGENTS.md` — 에이전트 지침·워크플로우 요약
- `docs/context/model_spec.md` — 도메인 모델 스펙 (초안)
- `docs/architecture/architecture_spec.md` — 아키텍처 스펙 (초안)
- `docs/workflow/development_flow.md` — 이슈 기반 개발·브랜치·PR 절차
- `docs/features/feature_spec.md` — 기능 명세·구현 상태 (초안)
- `docs/conventions/convention.md` — 코드 컨벤션
- `docs/progress/` — 일자별 작업 기록
- `docs/releases/` — 버전별 출시노트

## 개발 방식

모든 작업은 GitHub 이슈 기반으로 진행합니다
(이슈 등록 → 개발자 확인 → 브랜치 → 개발 → PR → 개발자 승인·머지).
상세 절차는 `docs/workflow/development_flow.md`를 따릅니다.
