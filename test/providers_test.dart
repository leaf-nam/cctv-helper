import 'package:cctv_helper/core/services/local_store.dart';
import 'package:cctv_helper/features/cases/providers/cases_provider.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/sources/providers/sources_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CasesProvider', () {
    test('사건 추가·이름 변경·삭제', () async {
      final provider = CasesProvider();
      await provider.addCase('사건1');
      expect(provider.cases.length, 1);

      final id = provider.cases.first.id;
      await provider.renameCase(id, '사건1-수정');
      expect(provider.getById(id)?.title, '사건1-수정');

      await provider.removeCase(id);
      expect(provider.cases, isEmpty);
    });

    test('빈 제목 추가 무시', () async {
      final provider = CasesProvider();
      await provider.addCase('   ');
      expect(provider.cases, isEmpty);
    });

    test('사건 순서 변경', () async {
      final provider = CasesProvider();
      await provider.addCase('사건1');
      await provider.addCase('사건2');
      expect(provider.cases.first.title, '사건1');
      await provider.reorder(0, 1);
      expect(provider.cases.first.title, '사건2');
      expect(provider.cases.last.title, '사건1');
    });

    test('로컬 저장·복원', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);

      final writer = CasesProvider(null, store);
      await writer.addCase('저장사건');
      expect(writer.cases.length, 1);

      final reader = CasesProvider(null, store);
      await reader.load();
      expect(reader.cases.length, 1);
      expect(reader.cases.first.title, '저장사건');

      // CCTV·기록도 함께 저장·복원
      final caseId = reader.cases.first.id;
      final sources = SourcesProvider(null, store);
      await sources.addSource(caseId, '입구');
      final events = EventsProvider(null, store);
      final source = sources.byCase(caseId).first;
      await sources.updateTimes(
        source.id,
        displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
        actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
      );
      await events.addEvent(
        caseId: caseId,
        source: sources.getById(source.id)!,
        displayedAt: DateTime(2026, 10, 8, 15, 0, 0),
        memo: '메모',
      );

      final sources2 = SourcesProvider(null, store);
      await sources2.load();
      expect(sources2.byCase(caseId).length, 1);
      expect(sources2.byCase(caseId).first.offsetMillis, 120000);
      final events2 = EventsProvider(null, store);
      await events2.load();
      expect(events2.byCase(caseId).length, 1);
      expect(events2.byCase(caseId).first.memo, '메모');
    });
  });

  group('SourcesProvider', () {
    test('CCTV 추가·이름 변경·시간 입력·순서 변경·삭제', () async {
      final provider = SourcesProvider();
      await provider.addSource('case1', '입구');
      await provider.addSource('case1', '출구');
      expect(provider.byCase('case1').length, 2);
      // 실제 시각은 현재시간으로 초기화, CCTV 시각은 미입력
      for (final s in provider.byCase('case1')) {
        expect(s.actualAt, isNotNull);
        expect(s.displayedAt, isNull);
        expect(s.offsetMillis, isNull);
      }

      final first = provider.byCase('case1').first;
      await provider.renameSource(first.id, '정문');
      expect(provider.getById(first.id)?.name, '정문');

      await provider.updateTimes(
        first.id,
        displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
        actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
      );
      expect(provider.getById(first.id)?.offsetMillis, 120000);

      await provider.reorder('case1', 0, 1);
      expect(provider.byCase('case1').first.name, '출구');

      await provider.removeSource(first.id);
      expect(provider.byCase('case1').length, 1);
    });
  });

  group('EventsProvider', () {
    test('기록 추가·보정시각 정렬·메모 수정·삭제', () async {
      final sources = SourcesProvider();
      await sources.addSource('case1', '입구');
      final source = sources.byCase('case1').first;
      await sources.updateTimes(
        source.id,
        displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
        actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
      );
      final synced = sources.getById(source.id)!;

      final events = EventsProvider();
      await events.addEvent(
        caseId: 'case1',
        source: synced,
        displayedAt: DateTime(2026, 10, 8, 16, 0, 0),
        memo: '두 번째',
      );
      await events.addEvent(
        caseId: 'case1',
        source: synced,
        displayedAt: DateTime(2026, 10, 8, 15, 0, 0),
        memo: '첫 번째',
      );
      final list = events.byCase('case1');
      expect(list.length, 2);
      expect(list.first.memo, '첫 번째');

      await events.updateMemo(list.first.id, '첫 번째-수정');
      expect(events.byCase('case1').first.memo, '첫 번째-수정');

      await events.removeEvent(list.first.id);
      expect(events.byCase('case1').length, 1);
    });
  });
}
