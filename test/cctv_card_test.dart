import 'package:cctv_helper/features/cases/providers/cases_provider.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/sources/presentation/case_detail_screen.dart';
import 'package:cctv_helper/features/sources/providers/sources_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

typedef CaseSetup = ({
  CasesProvider cases,
  SourcesProvider sources,
  EventsProvider events,
  String caseId,
});

Future<CaseSetup> pumpCase(
  WidgetTester tester, {
  DateTime? displayedAt,
  DateTime? actualAt,
  Size? surfaceSize,
  double textScale = 1.0,
}) async {
  final cases = CasesProvider();
  final sources = SourcesProvider();
  final events = EventsProvider();
  await cases.addCase('사건1');
  final caseId = cases.cases.first.id;
  await sources.addSource(caseId, '입구');
  if (displayedAt != null || actualAt != null) {
    await sources.updateTimes(
      sources.byCase(caseId).first.id,
      displayedAt: displayedAt == null ? null : () => displayedAt,
      actualAt: actualAt == null ? null : () => actualAt,
    );
  }

  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cases),
        ChangeNotifierProvider.value(value: sources),
        ChangeNotifierProvider.value(value: events),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: CaseDetailScreen(caseId: caseId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (cases: cases, sources: sources, events: events, caseId: caseId);
}

Future<void> fillTimeParts(
  WidgetTester tester, {
  required List<String> values,
}) async {
  for (var i = 0; i < values.length; i++) {
    final field = find.byKey(ValueKey('time-part-$i'));
    expect(field, findsOneWidget);
    await tester.enterText(field, values[i]);
    await tester.pumpAndSettle();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('확인 시간이 기록 시각으로 이어쓰기', (tester) async {
    final setup = await pumpCase(
      tester,
      displayedAt: DateTime(2026, 10, 8, 14, 0, 0),
      actualAt: DateTime(2026, 10, 8, 14, 2, 0),
    );

    await tester.tap(find.widgetWithText(TextButton, 'CCTV 시각 입력'));
    await tester.pumpAndSettle();
    await fillTimeParts(tester, values: ['2026', '10', '08', '15', '00', '00']);
    await tapVisible(tester, find.byKey(const ValueKey('time-apply')));

    // 확인 결과가 날짜/시간 2줄로 분리 표시
    expect(find.text('CCTV 시각'), findsWidgets);
    expect(find.text('실제 시각'), findsWidgets);
    expect(find.text('2026-10-08'), findsWidgets);
    expect(find.text('15:00:00'), findsWidgets);
    expect(find.text('15:02:00'), findsOneWidget);

    // 기록 추가 시 확인된 시간이 초기값으로 들어감
    await tester.tap(find.widgetWithText(FilledButton, '기록 추가'));
    await tester.pumpAndSettle();
    expect(find.text('영상 시각'), findsOneWidget);
    expect(find.text('15:00:00'), findsWidgets);
    expect(setup.events.byCase(setup.caseId), isEmpty);
  });

  testWidgets('편집 시트: 적용 전에는 저장하지 않고 닫기로 취소', (tester) async {
    final setup = await pumpCase(
      tester,
      actualAt: DateTime(2026, 10, 8, 14, 2, 0),
    );

    // 실제 시각 행(두 번째 입력 버튼)에서 열었으므로 actualAt 대상
    await tester.tap(find.widgetWithText(TextButton, '입력').at(1));
    await tester.pumpAndSettle();

    expect(find.text('−1일'), findsOneWidget);
    expect(find.text('+1일'), findsOneWidget);
    expect(find.text('−1초'), findsOneWidget);
    expect(find.text('+1초'), findsOneWidget);

    await fillTimeParts(tester, values: ['2026', '10', '08', '14', '00', '00']);
    // 적용 전에는 draft만 바뀌고 저장되지 않는다.
    expect(
      setup.sources.byCase(setup.caseId).first.actualAt,
      DateTime(2026, 10, 8, 14, 2, 0),
    );

    await tapVisible(tester, find.byKey(const ValueKey('time-apply')));
    expect(
      setup.sources.byCase(setup.caseId).first.actualAt,
      DateTime(2026, 10, 8, 14, 0, 0),
    );

    // 다시 열어 잘못된 값 입력 후 닫기 → 적용하지 않고 취소
    await tester.tap(find.widgetWithText(TextButton, '입력').at(1));
    await tester.pumpAndSettle();
    await fillTimeParts(tester, values: ['2026', '10', '08', '14', '70', '00']);
    expect(find.text('유효하지 않은 날짜/시간입니다.'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('time-close')));
    expect(find.text('적용하지 않고 닫을까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '닫기'));
    await tester.pumpAndSettle();

    expect(
      setup.sources.byCase(setup.caseId).first.actualAt,
      DateTime(2026, 10, 8, 14, 0, 0),
    );
  });

  testWidgets('시각 행 분리 및 지금 버튼 표시', (tester) async {
    final setup = await pumpCase(tester);

    final actualLabel = find.text('실제 시각');
    final cctvLabel = find.text('CCTV 시각');
    expect(actualLabel, findsOneWidget);
    expect(cctvLabel, findsOneWidget);
    expect(
      tester.getTopLeft(cctvLabel).dy,
      lessThan(tester.getTopLeft(actualLabel).dy),
    );
    expect(find.text('기준'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '입력'), findsNWidgets(2));
    expect(find.widgetWithText(TextButton, '지금'), findsNWidgets(2));
    expect(find.text('시간 확인'), findsNothing);
    expect(find.widgetWithText(FilledButton, '기록 추가'), findsNothing);

    final source = setup.sources.byCase(setup.caseId).first;
    await setup.sources.updateTimes(
      source.id,
      displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
      actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('CCTV가 2분 0초 느림'), findsOneWidget);
    expect(find.text('시간 확인'), findsOneWidget);
    expect(find.text('CCTV 시간을 입력하세요.'), findsOneWidget);
  });

  testWidgets('행에서 날짜/시간 바로 타이핑 입력', (tester) async {
    final setup = await pumpCase(tester);

    await tester.enterText(
      find.byKey(const ValueKey('inline-date')).first,
      '2026-10-08',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inline-time')).first,
      '14:00:00',
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    final updated = setup.sources.byCase(setup.caseId).first;
    expect(updated.displayedAt, DateTime(2026, 10, 8, 14, 0, 0));
    expect(find.text('시간 확인'), findsOneWidget);
  });

  testWidgets('기록 목록에서 CCTV/실제 시간 시작점 정렬', (tester) async {
    final setup = await pumpCase(
      tester,
      displayedAt: DateTime(2026, 10, 8, 14, 0, 0),
      actualAt: DateTime(2026, 10, 8, 14, 2, 0),
    );
    final source = setup.sources.byCase(setup.caseId).first;
    await setup.events.addEvent(
      caseId: setup.caseId,
      source: source,
      displayedAt: DateTime(2026, 10, 8, 14, 0, 0),
      memo: '차량 통과',
    );
    await setup.events.addEvent(
      caseId: setup.caseId,
      source: source,
      displayedAt: DateTime(2026, 10, 8, 15, 0, 0),
      memo: '인물 통과',
    );
    await tester.pumpAndSettle();

    final eventId = setup.events.byCase(setup.caseId).first.id;
    final cctv = find.byKey(ValueKey('record-cctv-$eventId'));
    final actual = find.byKey(ValueKey('record-actual-$eventId'));
    expect(cctv, findsOneWidget);
    expect(actual, findsOneWidget);
    expect(tester.getTopLeft(cctv).dx, tester.getTopLeft(actual).dx);
  });

  testWidgets('작은 화면·큰 글꼴에서도 시각 2줄 표시가 넘치지 않음', (tester) async {
    await pumpCase(
      tester,
      displayedAt: DateTime(2026, 10, 8, 14, 0, 0),
      actualAt: DateTime(2026, 10, 8, 14, 2, 0),
      surfaceSize: const Size(320, 568),
      textScale: 1.3,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('2026-10-08'), findsWidgets);
    expect(find.text('14:00:00'), findsWidgets);
    expect(find.text('14:02:00'), findsOneWidget);
  });

  testWidgets('작은 화면에서도 시각 편집 시트가 넘치지 않음', (tester) async {
    await pumpCase(
      tester,
      actualAt: DateTime(2026, 10, 8, 14, 2, 0),
      surfaceSize: const Size(320, 568),
      textScale: 1.3,
    );

    await tester.tap(find.byTooltip('입력').at(1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('time-apply')), findsOneWidget);
    expect(find.byKey(const ValueKey('time-close')), findsOneWidget);
  });

  testWidgets('스테퍼를 길게 누르면 연속 증감', (tester) async {
    final setup = await pumpCase(
      tester,
      actualAt: DateTime(2026, 10, 8, 14, 2, 0),
    );
    await tester.tap(find.widgetWithText(TextButton, '입력').at(1));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('+1초')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('time-apply')));
    final updated = setup.sources.byCase(setup.caseId).first.actualAt!;
    expect(updated.second, greaterThanOrEqualTo(2));
  });
}
