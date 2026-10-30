import 'package:cctv_helper/core/services/time_calc_service.dart';
import 'package:cctv_helper/features/cases/providers/cases_provider.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/photos/domain/case_photo.dart';
import 'package:cctv_helper/features/photos/presentation/photos_screen.dart';
import 'package:cctv_helper/features/photos/providers/photos_provider.dart';
import 'package:cctv_helper/features/sources/providers/sources_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<(CasesProvider, SourcesProvider, PhotosProvider, String)> pump(
    WidgetTester tester, {
    bool withPhoto = true,
  }) async {
    final cases = CasesProvider();
    final sources = SourcesProvider();
    final events = EventsProvider();
    final photos = PhotosProvider();
    await cases.addCase('사건1');
    final caseId = cases.cases.first.id;
    await sources.addSource(caseId, '입구');
    final source = sources.byCase(caseId).first;
    await sources.updateTimes(
      source.id,
      displayedAt: () => DateTime(2026, 10, 22, 14),
      actualAt: () => DateTime(2026, 10, 22, 14, 2),
    );
    if (withPhoto) {
      await photos.addExisting(
        CasePhoto.create(
          caseId: caseId,
          sourceId: source.id,
          filePath: '',
          kind: CasePhotoKind.scene,
          displayedAt: DateTime(2026, 10, 22, 15),
          offsetMillis: 120000,
          memo: '현장 사진',
        ),
      );
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cases),
          ChangeNotifierProvider.value(value: sources),
          ChangeNotifierProvider.value(value: events),
          ChangeNotifierProvider.value(value: photos),
        ],
        child: MaterialApp(home: PhotosScreen(caseId: caseId)),
      ),
    );
    await tester.pumpAndSettle();
    return (cases, sources, photos, caseId);
  }

  testWidgets('CCTV별 그룹·장수·보정시간 표시', (tester) async {
    await pump(tester);
    expect(find.text('사진 보관함'), findsOneWidget);
    expect(find.text('입구'), findsOneWidget);
    expect(find.text('1장'), findsOneWidget);
    expect(find.text('장면'), findsOneWidget);
    expect(find.text('2026-10-22 15:02:00'), findsOneWidget);
  });

  testWidgets('사진 상세에서 메모 수정·삭제 진입점 제공', (tester) async {
    final setup = await pump(tester);
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('보정 실제시간'), findsOneWidget);
    expect(find.text('메모 수정'), findsOneWidget);
    expect(find.text('현장 사진'), findsOneWidget);

    await tester.tap(find.text('메모 수정'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '수정된 메모');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(setup.$3.byCase(setup.$4).first.memo, '수정된 메모');
  });

  testWidgets('사진이 없으면 빈 상태 안내', (tester) async {
    await pump(tester, withPhoto: false);
    expect(find.textContaining('아직 보관한 사진이 없습니다'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, '사진 추가'), findsOneWidget);
  });

  test('사진 보정시각은 오프셋 적용', () {
    final photo = CasePhoto.create(
      caseId: 'c',
      sourceId: 's',
      filePath: '',
      displayedAt: DateTime(2026, 10, 22, 14),
      offsetMillis: 120000,
    );
    expect(
      photo.correctedAt,
      TimeCalcService.correctedAt(
        displayedAt: DateTime(2026, 10, 22, 14),
        offsetMillis: 120000,
      ),
    );
  });
}
