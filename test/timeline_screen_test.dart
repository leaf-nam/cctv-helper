import 'package:cctv_helper/features/cases/providers/cases_provider.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/photos/providers/photos_provider.dart';
import 'package:cctv_helper/features/sources/providers/sources_provider.dart';
import 'package:cctv_helper/features/timeline/presentation/case_timeline_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<String> pumpTimeline(WidgetTester tester) async {
    final cases = CasesProvider();
    final sources = SourcesProvider();
    final events = EventsProvider();
    final photos = PhotosProvider();
    await cases.addCase('사건1');
    final caseId = cases.cases.first.id;
    await sources.addSource(caseId, '입구');
    await sources.addSource(caseId, '출구');
    final entrance = sources.byCase(caseId).first;
    final exit = sources.byCase(caseId).last;
    await sources.updateTimes(
      entrance.id,
      displayedAt: () => DateTime(2026, 10, 22, 14),
      actualAt: () => DateTime(2026, 10, 22, 14, 2),
    );
    await sources.updateTimes(
      exit.id,
      displayedAt: () => DateTime(2026, 10, 22, 14),
      actualAt: () => DateTime(2026, 10, 22, 13, 59),
    );

    await events.addEvent(
      caseId: caseId,
      source: sources.getById(entrance.id)!,
      displayedAt: DateTime(2026, 10, 22, 15),
      memo: '입구 기록',
    );
    await events.addEvent(
      caseId: caseId,
      source: sources.getById(exit.id)!,
      displayedAt: DateTime(2026, 10, 22, 14, 30),
      memo: '출구 기록',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cases),
          ChangeNotifierProvider.value(value: sources),
          ChangeNotifierProvider.value(value: events),
          ChangeNotifierProvider.value(value: photos),
        ],
        child: MaterialApp(home: CaseTimelineScreen(caseId: caseId)),
      ),
    );
    await tester.pumpAndSettle();
    return caseId;
  }

  testWidgets('기록을 보정시각 오름차순으로 표시하고 날짜 헤더를 붙인다', (tester) async {
    await pumpTimeline(tester);

    expect(find.text('사건1 타임라인'), findsOneWidget);
    expect(find.text('2026-10-22'), findsOneWidget);
    expect(find.text('2건'), findsOneWidget);

    final exitY = tester.getTopLeft(find.text('출구 기록')).dy;
    final entranceY = tester.getTopLeft(find.text('입구 기록')).dy;
    expect(exitY, lessThan(entranceY), reason: '출구 14:29 → 입구 15:02 순서');

    expect(find.text('14:29:00'), findsOneWidget);
    expect(find.text('15:02:00'), findsOneWidget);
  });

  testWidgets('CCTV 필터로 특정 CCTV만 볼 수 있다', (tester) async {
    await pumpTimeline(tester);
    await tester.tap(find.widgetWithText(FilterChip, '출구'));
    await tester.pumpAndSettle();
    expect(find.text('출구 기록'), findsOneWidget);
    expect(find.text('입구 기록'), findsNothing);
  });

  testWidgets('항목을 누르면 상세 시트에 오프셋·시각을 표시', (tester) async {
    await pumpTimeline(tester);
    await tester.tap(find.text('입구 기록'));
    await tester.pumpAndSettle();
    expect(find.text('오프셋'), findsOneWidget);
    expect(find.text('+0일 0시 2분 0초'), findsOneWidget);
    expect(find.textContaining('ms'), findsNothing);
  });
}
