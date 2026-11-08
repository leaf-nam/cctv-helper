import 'package:cctv_helper/features/cases/providers/cases_provider.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/ocr/data/ocr_service.dart';
import 'package:cctv_helper/features/sources/domain/cctv_source.dart';
import 'package:cctv_helper/features/sources/presentation/event_sheet.dart';
import 'package:cctv_helper/features/sources/providers/sources_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// 메모(기록) 시트에서 첨부 사진으로 시각을 인식하는 흐름 (#45).
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

void main() {
  Future<(String, CctvSource)> pumpHarness(
    WidgetTester tester, {
    required OcrService ocr,
    required ImagePicker picker,
  }) async {
    final cases = CasesProvider();
    final sources = SourcesProvider();
    final events = EventsProvider();
    await cases.addCase('사건1');
    final caseId = cases.cases.first.id;
    await sources.addSource(caseId, '입구');
    final source = sources.byCase(caseId).first;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cases),
          ChangeNotifierProvider.value(value: sources),
          ChangeNotifierProvider.value(value: events),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showEventSheet(
                    context,
                    caseId,
                    source,
                    ocrService: ocr,
                    imagePicker: picker,
                  ),
                  child: const Text('기록 열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('기록 열기'));
    await tester.pumpAndSettle();
    return (caseId, source);
  }

  testWidgets('첨부한 사진을 다시 고르지 않고 그대로 인식한다', (tester) async {
    final picker = _FakePicker('attached.jpg');
    final ocr = _FakeOcr('CCTV 2026-10-22 14:03:22');
    await pumpHarness(tester, ocr: ocr, picker: picker);

    // 사진 첨부 (앨범)
    await tester.tap(find.widgetWithText(OutlinedButton, '앨범에서 선택'));
    await tester.pumpAndSettle();
    expect(picker.calls, 1);
    expect(find.text('첨부 사진에서 시각 인식'), findsOneWidget);

    // 첨부 사진으로 바로 인식: 사진 선택기가 다시 호출되지 않는다.
    await tester.tap(find.byKey(const ValueKey('event-ocr')));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(ocr.calls, ['attached.jpg']);
    expect(find.textContaining('인식된 시각'), findsOneWidget);
    expect(find.text('14:03:22'), findsOneWidget);
  });

  testWidgets('사진이 없을 때만 촬영·앨범 선택을 요청한다', (tester) async {
    final picker = _FakePicker('picked.jpg');
    final ocr = _FakeOcr('2026-10-22 09:05:00');
    await pumpHarness(tester, ocr: ocr, picker: picker);

    await tester.tap(find.byKey(const ValueKey('event-ocr')));
    await tester.pumpAndSettle();

    // 선택 시트(ListTile 2개)가 뜨고 아직 사진 선택기는 호출되지 않았다.
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(picker.calls, 0);

    await tester.tap(find.widgetWithText(ListTile, '앨범에서 선택'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(ocr.calls, ['picked.jpg']);
    expect(find.text('09:05:00'), findsOneWidget);
  });
}
