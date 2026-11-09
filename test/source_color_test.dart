import 'package:cctv_helper/core/theme/source_palette.dart';
import 'package:cctv_helper/features/cases/providers/cases_provider.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/sources/domain/cctv_source.dart';
import 'package:cctv_helper/features/sources/presentation/case_detail_screen.dart';
import 'package:cctv_helper/features/sources/providers/sources_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// CCTV 색상이 사건 상세 카드·기록 목록에서도 일관되게 적용되는지 (#43).
void main() {
  test('사건 내 CCTV 순서로 색을 배정한다', () {
    final first = CctvSource.create(caseId: 'c', name: '입구');
    final second = CctvSource.create(caseId: 'c', name: '주차장');
    final sources = [first, second];
    // 순수 팔레트 규칙 확인 (사건 상세·사진 보관함·타임라인이 공유).
    expect(SourcePalette.forSource(sources, first.id), SourcePalette.of(0));
    expect(SourcePalette.forSource(sources, second.id), SourcePalette.of(1));

    // 사용자가 고른 색이 있으면 순서보다 우선한다.
    final picked = [
      first.copyWith(colorIndex: () => 7),
      second.copyWith(colorIndex: () => 12),
    ];
    expect(SourcePalette.forSource(picked, first.id), SourcePalette.of(7));
    expect(SourcePalette.forSource(picked, second.id), SourcePalette.of(12));
  });

  test('테마 색상은 같은 채도의 20가지 색이다', () {
    expect(SourcePalette.colors, hasLength(20));
    for (final color in SourcePalette.colors) {
      expect(HSLColor.fromColor(color).saturation, closeTo(0.62, 0.02));
    }
    expect(SourcePalette.colors.toSet(), hasLength(20));
  });

  testWidgets('CCTV 카드와 기록 목록에 같은 CCTV 색을 표시', (tester) async {
    final cases = CasesProvider();
    final sources = SourcesProvider();
    final events = EventsProvider();
    await cases.addCase('사건1');
    final caseId = cases.cases.first.id;
    await sources.addSource(caseId, '입구');
    final source = sources.byCase(caseId).first;
    await sources.updateTimes(
      source.id,
      displayedAt: () => DateTime(2026, 10, 22, 14),
      actualAt: () => DateTime(2026, 10, 22, 14, 2),
    );
    await events.addEvent(
      caseId: caseId,
      source: source,
      displayedAt: DateTime(2026, 10, 22, 14, 10),
      memo: '입구 기록',
    );
    final event = events.bySource(source.id).single;

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

    Color dotColor(Key key) {
      final container = tester.widget<Container>(find.byKey(key));
      return (container.decoration! as BoxDecoration).color!;
    }

    expect(dotColor(ValueKey('cctv-color-${source.id}')), SourcePalette.of(0));

    // 카드가 기본으로 펼쳐져 기록 목록까지 보인다.
    expect(dotColor(ValueKey('record-color-${event.id}')), SourcePalette.of(0));

    // 색 점을 눌러 테마 색을 바꾸면 카드·기록 색이 함께 바뀐다.
    await tester.tap(find.byKey(ValueKey('cctv-color-button-${source.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('source-color-sheet')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('source-color-option-7')),
    );
    await tester.tap(find.byKey(const ValueKey('source-color-option-7')));
    await tester.pumpAndSettle();

    expect(sources.byCase(caseId).first.colorIndex, 7);
    expect(dotColor(ValueKey('cctv-color-${source.id}')), SourcePalette.of(7));
    expect(dotColor(ValueKey('record-color-${event.id}')), SourcePalette.of(7));
  });
}
