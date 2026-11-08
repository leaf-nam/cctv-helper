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
    좁은 화면에서도 `10월`이 줄바꿈되지 않도록 한 줄 고정 + `FittedBox` 축소.
  - 시각 입력 필드의 `년/월/일/시/분/초` 접미사를 필드 내부(`suffixText`)에 배치해 잘림 방지.
  - 저장된 ISO8601(UTC) 시각을 `fromMap()`에서 `toLocal()`로 복원해 재시작 후에도 로컬 시각 표시.
  - CCTV 카드 전체를 접고 펼칠 수 있으며, 접힌 상태에서는 이름·오프셋·기록 건수만 표시.
  - 기록 목록 헤더의 화살표로 목록을 접고 펼칠 수 있음.
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
  - 기록 목록의 `CCTV`/`실제` 라벨은 고정폭으로, 시각은 같은 시작점에서 표시한다.
  - 기록 항목의 수정 버튼으로 메모를 편집한다. 저장 시 `EventsProvider.updateMemo()`를 호출하고,
    취소하거나 변경이 없으면 저장하지 않는다. 빈 메모는 `(메모 없음)`으로 표시한다.
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

## 7. 통합 보정 타임라인 (#7, 1.1.0 구현됨)

- **요구**: 사건 하나의 모든 CCTV 기록·사진을 보정된 실제시간 기준으로 통합 정렬.
- **구현 상태**: 구현됨.
- **동작**:
  - `/case/:id/timeline` 라우트, 사건 상세 앱바의 타임라인 버튼으로 진입.
  - `TimelineEntry.build()`가 `TimelineEvent`와 `CasePhoto`를 보정시각 오름차순으로 합친다.
  - 날짜별 헤더(건수 포함), 시간축(초 단위), CCTV별 색상·필터 칩, 썸네일,
    오프셋 배지, 빈 상태 안내.
  - 항목 탭 → 상세 시트(CCTV 시각·보정 실제시간·오프셋·메모·사진).
  - `ListView.builder`로 100건 이상에서도 스크롤 성능 유지.
  - 그래프 뷰는 목록형 타임라인 이후 후속 검토.

## 8. 첫 실행 튜토리얼 (#25, #33, 1.0.1 구현됨)

- **요구**: 첫 실행 시 앱 사용 흐름을 4단계로 안내하고, 다시 보기 진입점을 제공한다.
- **구현 상태**: 구현됨.
- **동작**:
  - 첫 실행(`tutorialSeen=false`)이면 사건 목록 진입 후 `/onboarding`으로 이동.
  - ① 사건 만들기 ② 실제시간/CCTV 시간 입력 ③ 오차 확인 ④ 기록·타임라인.
  - 각 단계에 실제 앱 화면 예시 이미지 4장(`assets/tutorial/`)을 함께 표시.
  - 도움말 본문은 `WordWrapText`로 공백 기준 단어 단위 줄바꿈(좁은 화면·큰 글꼴 대응).
  - `다음`/`이전`/`건너뛰기`/`시작하기`, 페이지 인디케이터.
  - `건너뛰기` 또는 마지막 `시작하기`에서 `tutorialSeen=true` 저장.
  - 사건 목록 앱바의 도움말 버튼으로 `튜토리얼 다시 보기`.
- **관련 코드**:
  - `lib/features/onboarding/providers/tutorial_provider.dart`
  - `lib/features/onboarding/presentation/tutorial_screen.dart`
  - `lib/core/widgets/word_wrap_text.dart`
  - `lib/routing/app_router.dart` (`/onboarding`)
  - `lib/core/constants/store_keys.dart` (`tutorialSeen`)
  - `assets/tutorial/01-cases.png` … `04-records.png` (`pubspec.yaml` assets)

## 9. 사진 파일 로컬 보관 인프라 (#26, 1.1.0 구현됨)

- **요구**: OS 캐시 정리로 사진이 유실되지 않도록 앱 문서 디렉터리에 보관한다.
- **구현 상태**: 구현됨.
- **관련 코드**:
  - `lib/core/services/photo_storage_service.dart` (`PhotoStorageService`)
  - 저장 구조: `cases/<caseId>/sources/<sourceId>/<prefix>_<timestamp>.<ext>`
  - `TimelineEvent.photoPaths` (기존 `photoPath` 호환 읽기), `CasePhoto.filePath`
  - 앱 시작 시 기존 절대 경로 → 상대 경로 마이그레이션, 원본 유실 시 placeholder
  - 사건/CCTV/기록 삭제 시 파일 정리, 보관 용량 계산(`totalBytes`)
- **검증**: temp 디렉터리 단위 테스트, 마이그레이션·삭제 테스트.

## 10. OCR 시간 자동 인식 (#27, 1.1.0 구현됨)

- **요구**: 실제시간 화면/CCTV LIVE 화면/녹화장면 사진에서 시각을 인식한다.
- **구현 상태**: 구현됨 (온디바이스 ML Kit, 모바일 전용).
- **동작**:
  - A. 기준 촬영: CCTV 카드 `사진으로 입력` → 실제시간·CCTV 사진 2장을 각각 OCR →
    후보 시각 표시 → 사용자 확인·수정 → `적용` 시 오프셋 저장 + 기준 사진 보관.
  - B. 녹화장면: 기록 시트/사진 추가 시트의 `사진에서 시각 인식` → CCTV 시각 후보 →
    저장된 오프셋으로 보정 실제시간 산출. 자동 확정하지 않는다.
  - 인식 실패·권한 거부·저화질: 수동 입력 fallback과 안내 문구.
- **관련 코드**:
  - `lib/features/ocr/data/ocr_service.dart` (+ ML Kit/스텁 구현)
  - `lib/features/ocr/domain/timestamp_parser.dart`
  - `lib/features/ocr/presentation/baseline_ocr_sheet.dart`
- **시각 표기 지원 (#38)**:
  - `yyyy-MM-dd`, `yyyy/MM/dd`, `MM/dd/yyyy`, `yyyyMMdd`, 한글 단위, 14자리 압축,
    AM/PM, 전각 문자.
  - 영어 월 이름: `Oct 30 9:11 PM`, `OCT.30.2026 21:11:05`, `30-Oct-2026 21:11:05`,
    `Oct 30, 2026 09:05:00`, `2026 OCT 30 21:11:05`. 약어·전체 이름 모두 허용.
  - 영어 표기에 **연도가 없으면** fallback 날짜(없으면 오늘)의 연도를 쓰고,
    결과가 fallback보다 하루 넘게 미래면 작년으로 보정한다 (CCTV 캡처는 과거 기록).
  - 범위 초과(`OCT 45 2026`, `FEB 30 2026`)는 후보에서 제외.
- **플랫폼 지원**: ML Kit는 android/ios 전용이라 macOS 데스크톱에서는 인식이
  동작하지 않는다(플러그인에 macOS 구현 없음). 실기기·시뮬레이터에서 확인한다.
- **검증**: 타임스탬프 파서 형식·범위·영어 월 이름·연도 추정 단위 테스트.
  실기기 OCR은 수동 확인 필요.

## 11. 사건·CCTV별 사진 보관함 (#28, 1.1.0 구현됨)

- **요구**: 사건별 폴더, CCTV별 그룹으로 촬영·캡처 사진을 보관한다.
- **구현 상태**: 구현됨.
- **동작**:
  - `/case/:id/photos` 라우트, 사건 상세 앱바의 사진 버튼으로 진입.
  - CCTV별 그룹 헤더(색상·오프셋·장수), 보정 실제시간 순 그리드.
  - 카메라/앨범 추가, 유형(기준/장면/기타), 메모, OCR 시각 인식, 삭제.
  - 사진 상세 시트: 촬영 시각·CCTV 시각·오프셋·보정 실제시간·메모, 메모 수정.
  - CCTV 필터, 빈 상태 안내.
- **관련 코드**: `lib/features/photos/*`, `showAddPhotoSheet()`.
- **검증**: provider 단위 테스트(저장·정렬·정리), 화면 위젯 테스트.

## 12. 시각 표시 가독성 개선 (#35, 1.1.0 구현됨)

- **요구**: 날짜·시간 글자 크기를 키우고 라벨/값 구분을 명확히 한다.
- **구현 상태**: 구현됨.
- **동작**:
  - 공용 `DateTimeText`/`DateTimeInlineText` (`lib/core/widgets/time_text.dart`).
  - 날짜는 `bodyMedium` 이상 + 보조 색, 시간은 20sp(목록 16sp)·굵기 600·고정폭 숫자.
  - 기준 카드, 시간 확인, 기록 목록, 기록 시트, 사진 보관함, 통합 타임라인에 적용.
  - 스크린리더에는 날짜+시간을 한 문장으로 제공.
- **검증**: 표시 크기·고정폭 위젯 테스트.

## 13. 시각 직접 입력 범위 검증 (#36, 1.1.0 구현됨)

- **요구**: `7777777` 같은 자릿수·범위 초과 입력을 차단하고 명확히 안내한다.
- **구현 상태**: 구현됨.
- **동작**:
  - `dateInputFormatters()`/`timeInputFormatters()` = `GroupedDigitsInputFormatter`.
    사용자는 **숫자만** 입력하고 구분자는 자동 삽입된다
    (날짜 `20261022` → `2026-10-22`, 시간 `140322` → `14:03:22`).
    그룹이 차면 구분자를 미리 보여 주고(`14` → `14:`), 구분자를 지우면
    앞 숫자까지 함께 지워 자연스럽게 줄어든다. 최대 자릿수 초과분은 무시한다.
  - `validateDateInput()`/`validateTimeInput()`: 연 1900~2100, 실제 존재하는 날짜,
    시 0~23, 분/초 0~59.
  - **경고는 범위를 벗어날 때만** 표시한다. 자릿수가 모자란 입력 중에는 경고하지
    않고(`incomplete`), 포커스를 잃거나 제출할 때만 "8자리를 입력하세요"류 안내를 준다.
  - 인라인 직접 입력: 오류 문구 표시 + 유효하지 않은 값 저장 차단.
  - 시각 편집 시트의 6칸 입력도 동일 범위 규칙으로 적용 차단(각 칸 숫자만).
- **검증**: 마스크 포매터·검증 단위 테스트, `7777777`/`99:99:99` 및
  자동 구분자 위젯 테스트.

## 14. 1.1.1 UX 개선 (#42~#46)

- **CCTV별 색상 일관 적용 (#43, 구현됨)**
  - `SourcePalette`(사건 내 CCTV 순서) 색을 사건 상세 `CctvCard` 헤더와
    카드 안 기록 목록에도 표시한다 (`cctv-color-*`, `record-color-*`).
  - 사진 보관함·통합 타임라인과 같은 색을 쓰며, 색 외 이름·아이콘 정보는 유지한다.
- **한 사진 다중 시각 후보 선택 (#42, 구현됨)**
  - `TimestampParser.candidates()`가 한 글의 여러 시각을 각각 후보로 만든다
    (같은 시각의 중복 형식은 신뢰도 높은 것만 유지).
  - 기준 OCR 시트의 `한 장에 두 시각이 보이나요?` 모드에서 사진 한 장을 인식해
    후보를 실제시간/CCTV 슬롯에 각각 지정한다.
  - 슬롯별 인식도 후보가 2개 이상이면 `ChoiceChip`으로 선택한다.
  - 같은 사진을 양쪽 슬롯에 써도 `PhotosProvider`에는 한 번만 저장한다.
- **모달 하단 시스템 바 겹침 제거 (#44, 구현됨)**
  - `lib/core/widgets/modal_sheet.dart`의 `modalBottomInset()`/
    `modalSheetPadding()`이 `max(viewInsets.bottom, viewPadding.bottom)`을 반영한다.
  - 기준 OCR·기록 추가·사진 추가·시각 편집·사진 상세 시트에 적용.
- **메모 첨부 사진 OCR (#45, 구현됨)**
  - 기록 시트에 이미 첨부한 사진이 있으면 `ImagePicker`를 다시 호출하지 않고
    해당 경로로 OCR한다. 사진이 없을 때만 촬영/앨범 선택 시트를 띄운다.
  - OCR 서비스·이미지 선택기를 주입 가능하게 해 위젯 테스트로 검증한다.
- **사진 전체화면 뷰어 (#46, 구현됨)**
  - 사진 타일 탭 → `showPhotoViewer()` 전체화면(`InteractiveViewer` 핀치 줌·팬).
  - `정보` 버튼 → 기존 상세 시트(메모 수정·삭제), 닫기·시스템 뒤로가기 지원.
  - 다운로드/공유는 저장 권한·플러그인 검토가 필요해 후속 과제로 분리.

## 15. 기능-코드 매핑표

| # | 기능 | 저장 키 | 모델 | Repository | 화면/Provider | 상태 |
|---|------|--------|------|------------|---------------|------|
| 1 | 현재시간 입력 | `sources` | `CctvSource` | `CctvSourceRepository` | `CctvCard`, `SourcesProvider` | 구현됨 |
| 2 | 오차 계산 | — | — | — | `TimeCalcService` | 구현됨 |
| 3 | 이벤트 입력 | `events` | `TimelineEvent` | `TimelineEventRepository` | `event_sheet`, `EventsProvider` | 구현됨 |
| 4 | 사건별 CCTV 관리 | `cases`+`sources` | `CaseFile` | `CaseRepository` | `CasesScreen`·`CaseDetailScreen` | 구현됨 |
| 5 | 검색 | — | — | — | — | 미구현 (v1.2.0 예정) |
| 6 | 지도 | — | — | — | — | 미구현 (v1.2.0 예정) |
| 7 | 통합 타임라인 | `events`+`casePhotos` | `TimelineEntry` | `TimelineEventRepository`+`CasePhotoRepository` | `CaseTimelineScreen` | 구현됨 (1.1.0) |
| 8 | 첫 실행 튜토리얼 | `tutorialSeen` | — | — | `TutorialScreen`, `TutorialProvider` | 구현됨 |
| 9 | 사진 저장 인프라 (#26) | 파일 시스템 | `TimelineEvent.photoPaths` | `PhotoStorageService` | `EventsProvider`·`PhotosProvider` | 구현됨 (1.1.0) |
| 10 | OCR 시간 인식 (#27) | — | `TimestampCandidate` | `OcrService` | `BaselineOcrSheet`, 기록 시트 | 구현됨 (모바일) |
| 11 | 사진 보관함 (#28) | `casePhotos` | `CasePhoto` | `CasePhotoRepository` | `PhotosScreen`, `PhotosProvider` | 구현됨 (1.1.0) |
| 12 | 시각 표시 가독성 (#35) | — | — | — | `DateTimeText` | 구현됨 (1.1.0) |
| 13 | 입력 범위 검증 (#36) | — | — | — | `validateDateInput`/`validateTimeInput` | 구현됨 (1.1.0) |
| 14 | CCTV 색상 일관 적용 (#43) | — | — | — | `SourcePalette`, `CctvCard` | 구현됨 (1.1.1) |
| 15 | 다중 시각 후보 선택 (#42) | — | `TimestampCandidate` | `TimestampParser.candidates` | `BaselineOcrSheet` | 구현됨 (1.1.1) |
| 16 | 모달 하단 inset (#44) | — | — | — | `modalSheetPadding` | 구현됨 (1.1.1) |
| 17 | 첨부 사진 OCR (#45) | — | — | `OcrService` | `event_sheet` | 구현됨 (1.1.1) |
| 18 | 사진 전체화면 (#46) | — | `CasePhoto` | — | `photo_viewer`, `PhotosScreen` | 구현됨 (1.1.1) |
