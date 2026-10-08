import 'package:cctv_helper/features/cases/providers/cases_provider.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/sources/presentation/case_detail_screen.dart';
import 'package:cctv_helper/features/sources/providers/sources_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 새 시간 입력 UI 검증: 실제 행이 위·CCTV 행이 아래, 행별 입력/지금 버튼.
void main() {
  testWidgets('편집 시트: 가로 스테퍼 + 직접 입력', (tester) async {
    final cases = CasesProvider();
    final sources = SourcesProvider();
    final events = EventsProvider();
    await cases.addCase('사건1');
    final caseId = cases.cases.first.id;
    await sources.addSource(caseId, '입구');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cases),
          ChangeNotifierProvider.value(value: sources),
          ChangeNotifierProvider.value(value: events),
        ],
        child: MaterialApp(home: CaseDetailScreen(caseId: caseId)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '입력').first);
    await tester.pumpAndSettle();

    // 가로 2행 스테퍼 (윗행 −, 아랫행 +)
    expect(find.text('−1일'), findsOneWidget);
    expect(find.text('+1일'), findsOneWidget);
    expect(find.text('−1초'), findsOneWidget);
    expect(find.text('+1초'), findsOneWidget);

    // 직접 타이핑 입력 후 적용
    await tester.enterText(
      find.byType(TextField),
      '2026-10-08 14:00:00',
    );
    await tester.tap(find.widgetWithText(FilledButton, '적용'));
    await tester.pumpAndSettle();
    final updated = sources.byCase(caseId).first;
    // 실제 시각 행(첫 번째 입력 버튼)에서 열었으므로 actualAt 갱신
    expect(updated.actualAt, DateTime(2026, 10, 8, 14, 0, 0));
  });
  testWidgets('시각 행 분리 및 지금 버튼 표시', (tester) async {
    final cases = CasesProvider();
    final sources = SourcesProvider();
    final events = EventsProvider();
    await cases.addCase('사건1');
    final caseId = cases.cases.first.id;
    await sources.addSource(caseId, '입구');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: cases),
          ChangeNotifierProvider.value(value: sources),
          ChangeNotifierProvider.value(value: events),
        ],
        child: MaterialApp(home: CaseDetailScreen(caseId: caseId)),
      ),
    );
    await tester.pumpAndSettle();

    final actualLabel = find.text('실제 시각');
    final cctvLabel = find.text('CCTV 시각');
    expect(actualLabel, findsOneWidget);
    expect(cctvLabel, findsOneWidget);
    // 실제 행이 CCTV 행보다 위에 배치
    expect(
      tester.getTopLeft(actualLabel).dy,
      lessThan(tester.getTopLeft(cctvLabel).dy),
    );
    // 행별 입력/지금 버튼
    expect(find.widgetWithText(TextButton, '입력'), findsNWidgets(2));
    expect(find.widgetWithText(TextButton, '지금'), findsNWidgets(2));
    // 추가 시 실제 시각만 초기화 → CCTV 시각 미입력이라 오차 미계산
    expect(find.textContaining('미계산'), findsOneWidget);

    // CCTV 시각 입력 → 사람이 읽기 쉬운 오차 문장 표시
    final source = sources.byCase(caseId).first;
    await sources.updateTimes(
      source.id,
      displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
      actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('미계산'), findsNothing);
    expect(find.textContaining('CCTV가 2분 느림'), findsOneWidget);
  });
}
