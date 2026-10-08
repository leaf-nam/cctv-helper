import 'package:cctv_helper/features/cases/providers/cases_provider.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/sources/presentation/case_detail_screen.dart';
import 'package:cctv_helper/features/sources/providers/sources_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 새 시간 입력 UI 검증: 실제 행이 위·CCTV 행이 아래, 행별 입력/지금 버튼.
void main() {
  testWidgets('확인 시간이 기록 시각으로 이어쓰기', (tester) async {
    final cases = CasesProvider();
    final sources = SourcesProvider();
    final events = EventsProvider();
    await cases.addCase('사건1');
    final caseId = cases.cases.first.id;
    await sources.addSource(caseId, '입구');
    final source = sources.byCase(caseId).first;
    await sources.updateTimes(
      source.id,
      displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
      actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
    );

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

    // 시간 확인칸에 CCTV 시각 입력 후 시트 닫기
    await tester.tap(find.widgetWithText(TextButton, 'CCTV 시각 입력'));
    await tester.pumpAndSettle();
    final checkerField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    expect(checkerField, findsOneWidget);
    await tester.enterText(checkerField, '2026-10-08 15:00:00');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '닫기'));
    await tester.pumpAndSettle();
    // 확인 결과가 기준처럼 위아래 2행으로 분리 표시
    expect(find.text('CCTV 시각'), findsWidgets);
    expect(find.text('실제 시각'), findsWidgets);
    expect(find.text('2026-10-08 15:00:00'), findsWidgets);
    expect(find.text('2026-10-08 15:02:00'), findsOneWidget);

    // 기록 추가 시 확인된 시간이 초기값으로 들어감
    await tester.tap(find.widgetWithText(FilledButton, '기록 추가'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('영상 시각: 2026-10-08 15:00:00'),
      findsOneWidget,
    );
  });
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

    // 실제 시각 행(두 번째 입력 버튼)에서 열었으므로 actualAt 갱신
    await tester.tap(find.widgetWithText(TextButton, '입력').at(1));
    await tester.pumpAndSettle();

    // 가로 2행 스테퍼 (윗행 −, 아랫행 +)
    expect(find.text('−1일'), findsOneWidget);
    expect(find.text('+1일'), findsOneWidget);
    expect(find.text('−1초'), findsOneWidget);
    expect(find.text('+1초'), findsOneWidget);

    // 상단 시간 직접 타이핑 → Enter 없이 즉시 적용 (시트 안 입력칸)
    final sheetField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    expect(sheetField, findsOneWidget);
    await tester.enterText(sheetField, '2026-10-08 14:00:00');
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
    // CCTV 행이 위·실제 행이 아래에 배치 + 기준 박스 표기
    expect(
      tester.getTopLeft(cctvLabel).dy,
      lessThan(tester.getTopLeft(actualLabel).dy),
    );
    expect(find.text('기준'), findsOneWidget);
    // 행별 입력/지금 버튼
    expect(find.widgetWithText(TextButton, '입력'), findsNWidgets(2));
    expect(find.widgetWithText(TextButton, '지금'), findsNWidgets(2));
    // 추가 시 실제 시각만 초기화 → 하단 기능 숨김 + 안내 문구
    expect(find.textContaining('펼쳐집니다'), findsOneWidget);
    expect(find.text('시간 확인'), findsNothing);
    expect(find.widgetWithText(FilledButton, '기록 추가'), findsNothing);

    // CCTV 시각 입력 → 아코디언 전개, 사람이 읽기 쉬운 오차 문장 표시
    final source = sources.byCase(caseId).first;
    await sources.updateTimes(
      source.id,
      displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
      actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('펼쳐집니다'), findsNothing);
    expect(find.textContaining('CCTV가 2분 0초 느림'), findsOneWidget);
    // 기준 확정 후 시간 확인칸 표시
    expect(find.text('시간 확인'), findsOneWidget);
    expect(find.text('CCTV 시간을 입력하세요.'), findsOneWidget);
  });

  testWidgets('행에서 바로 타이핑 입력', (tester) async {
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

    // CCTV 행의 값 칸(첫 번째 TextField)에 바로 타이핑 → 기준 확정
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), '2026-10-08 14:00:00');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    final updated = sources.byCase(caseId).first;
    expect(updated.displayedAt, DateTime(2026, 10, 8, 14, 0, 0));
    expect(find.textContaining('펼쳐집니다'), findsNothing);
  });
}
