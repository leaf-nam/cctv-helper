import 'package:cctv_helper/features/ocr/data/ocr_service.dart';
import 'package:cctv_helper/features/ocr/presentation/baseline_ocr_sheet.dart';
import 'package:cctv_helper/features/photos/providers/photos_provider.dart';
import 'package:cctv_helper/features/sources/domain/cctv_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// 한 사진에 CCTV 시각과 실제시간이 함께 있을 때 후보를 골라 적용하는 흐름 (#42).
class _FakeOcr implements OcrService {
  _FakeOcr(this.text);

  final String? text;
  final List<String> calls = [];

  @override
  Future<String?> recognizeText(String imagePath) async {
    calls.add(imagePath);
    return text;
  }
}

class _FakePicker extends ImagePicker {
  _FakePicker(this.path);

  final String path;
  int calls = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls++;
    return XFile(path);
  }
}

class _ResultHolder {
  BaselineOcrResult? value;
}

void main() {
  Future<({PhotosProvider photos, _ResultHolder result})> pumpSheet(
    WidgetTester tester, {
    required _FakeOcr ocr,
    required _FakePicker picker,
  }) async {
    final photos = PhotosProvider();
    final source = CctvSource.create(caseId: 'case-1', name: '입구');
    final holder = _ResultHolder();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: photos,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    holder.value = await showBaselineOcrSheet(
                      context,
                      caseId: 'case-1',
                      source: source,
                      ocrService: ocr,
                      imagePicker: picker,
                    );
                  },
                  child: const Text('사진으로 입력 열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('사진으로 입력 열기'));
    await tester.pumpAndSettle();
    return (photos: photos, result: holder);
  }

  Future<void> pickSharedPhoto(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('baseline-shared-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '앨범에서 선택'));
    await tester.pumpAndSettle();
  }

  testWidgets('한 사진에서 두 시각을 골라 실제시간·CCTV에 각각 적용', (tester) async {
    final ocr = _FakeOcr('CCTV 2026-10-22 14:03:22\n실제 시계 2026-10-22 14:05:10');
    final picker = _FakePicker('shared.jpg');
    final setup = await pumpSheet(tester, ocr: ocr, picker: picker);

    // 사진 입력은 한 곳뿐이다 (슬롯별 촬영/앨범 버튼 없음).
    expect(find.byKey(const ValueKey('baseline-shared-pick')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '촬영'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, '앨범'), findsNothing);

    await pickSharedPhoto(tester);

    expect(picker.calls, 1);
    expect(ocr.calls, ['shared.jpg']);
    expect(
      find.byKey(const ValueKey('baseline-shared-actual-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('baseline-shared-cctv-1')),
      findsOneWidget,
    );

    // 후보 0 → 실제시간, 후보 1 → CCTV 시각
    await tester.ensureVisible(
      find.byKey(const ValueKey('baseline-shared-actual-0')),
    );
    await tester.tap(find.byKey(const ValueKey('baseline-shared-actual-0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('baseline-shared-cctv-1')),
    );
    await tester.tap(find.byKey(const ValueKey('baseline-shared-cctv-1')));
    await tester.pumpAndSettle();

    expect(find.text('14:03:22'), findsWidgets);
    expect(find.text('14:05:10'), findsWidgets);

    await tester.ensureVisible(find.byKey(const ValueKey('baseline-apply')));
    await tester.tap(find.byKey(const ValueKey('baseline-apply')));
    await tester.pumpAndSettle();

    expect(setup.result.value, isNotNull);
    expect(setup.result.value!.actualAt, DateTime(2026, 10, 22, 14, 3, 22));
    expect(setup.result.value!.displayedAt, DateTime(2026, 10, 22, 14, 5, 10));

    // 같은 사진을 두 번 저장하지 않는다.
    final stored = setup.photos.byCase('case-1');
    expect(stored, hasLength(1));
    expect(stored.first.filePath, 'shared.jpg');
  });

  testWidgets('같은 후보를 양쪽에 지정하면 반대 슬롯에서 비운다', (tester) async {
    final ocr = _FakeOcr('2026-10-22 14:03:22\n2026-10-22 14:05:10');
    final picker = _FakePicker('shared.jpg');
    await pumpSheet(tester, ocr: ocr, picker: picker);
    await pickSharedPhoto(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('baseline-shared-actual-0')),
    );
    await tester.tap(find.byKey(const ValueKey('baseline-shared-actual-0')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('baseline-actual-time')))
          .data,
      '14:03:22',
    );

    // 같은 후보를 CCTV에도 지정하면 실제시간 슬롯에서는 비운다.
    await tester.ensureVisible(
      find.byKey(const ValueKey('baseline-shared-cctv-0')),
    );
    await tester.tap(find.byKey(const ValueKey('baseline-shared-cctv-0')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('baseline-actual-time')))
          .data,
      '--:--:--',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('baseline-cctv-time')))
          .data,
      '14:03:22',
    );
  });
}
