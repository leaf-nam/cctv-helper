import 'package:cctv_helper/features/cases/providers/cases_provider.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/sources/presentation/case_detail_screen.dart';
import 'package:cctv_helper/features/sources/providers/sources_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 기록 시트 회귀 테스트.
/// - pop 애니메이션·키보드 정리 리빌드와 memoController dispose 경합
///   ("used after being disposed" → "_dependents.isEmpty" 연쇄 크래시)
/// - 저장 버튼 연타 시 중복 저장·하위 라우트 pop 방지
Future<({String caseId, EventsProvider events})> pumpReadyCase(
  WidgetTester tester,
) async {
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
  return (caseId: caseId, events: events);
}

Finder memoField() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '기록 메모',
    );

void main() {
  testWidgets('기록 추가: 중첩 시각시트 입력 후 저장', (tester) async {
    final setup = await pumpReadyCase(tester);
    await tester.tap(find.widgetWithText(FilledButton, '기록 추가'));
    await tester.pumpAndSettle();
    // 기록 시트의 [입력] (카드 2개 다음 세 번째)
    await tester.tap(find.widgetWithText(TextButton, '입력').at(2));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.enterText(
        find.byKey(ValueKey('time-part-$i')),
        ['2026', '10', '08', '16', '30', '00'][i],
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(TextButton, '닫기'));
    await tester.pumpAndSettle();
    await tester.enterText(memoField(), '수상한 인물');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('수상한 인물'), findsOneWidget);
    expect(setup.events.byCase(setup.caseId), hasLength(1));
  });

  testWidgets('기록 추가: 저장 버튼 연타 시 1건만 저장', (tester) async {
    final setup = await pumpReadyCase(tester);
    await tester.tap(find.widgetWithText(FilledButton, '기록 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(memoField(), '연타');
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, '저장');
    await tester.tap(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(setup.events.byCase(setup.caseId), hasLength(1));
  });
}
