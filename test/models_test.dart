import 'package:cctv_helper/features/cases/domain/case_file.dart';
import 'package:cctv_helper/features/events/domain/timeline_event.dart';
import 'package:cctv_helper/features/sources/domain/cctv_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaseFile', () {
    test('fromMap/toMap 라운드트립', () {
      final original = CaseFile.create(title: '편의점 사건', description: '메모');
      final restored = CaseFile.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.title, '편의점 사건');
      expect(restored.description, '메모');
    });

    test('copyWith 제목 변경', () {
      final original = CaseFile.create(title: '구제목');
      final copied = original.copyWith(title: '신제목');
      expect(copied.title, '신제목');
      expect(copied.id, original.id);
    });
  });

  group('CctvSource', () {
    test('시각 미입력 시 오프셋 null', () {
      final source = CctvSource.create(caseId: 'c1', name: '입구');
      expect(source.offsetMillis, isNull);
    });

    test('시각 입력 시 오프셋 자동 계산', () {
      final source = CctvSource.create(caseId: 'c1', name: '입구').copyWith(
        displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
        actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
      );
      expect(source.offsetMillis, 120000);
    });

    test('fromMap/toMap 라운드트립', () {
      final original = CctvSource.create(caseId: 'c1', name: '입구').copyWith(
        displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
        actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
      );
      final restored = CctvSource.fromMap(original.toMap());
      expect(restored.name, '입구');
      expect(restored.offsetMillis, 120000);
    });
  });

  group('TimelineEvent', () {
    test('생성 시 보정시각 자동 확정', () {
      final source = CctvSource.create(caseId: 'c1', name: '입구').copyWith(
        displayedAt: () => DateTime(2026, 10, 8, 14, 0, 0),
        actualAt: () => DateTime(2026, 10, 8, 14, 2, 0),
      );
      final event = TimelineEvent.create(
        caseId: 'c1',
        source: source,
        displayedAt: DateTime(2026, 10, 8, 15, 0, 0),
        memo: '용의자 등장',
        photoPath: '/tmp/img.jpg',
      );
      expect(event.correctedAt, DateTime(2026, 10, 8, 15, 2, 0));
      expect(event.memo, '용의자 등장');
      expect(event.photoPath, '/tmp/img.jpg');
    });

    test('fromMap/toMap 라운드트립', () {
      final source = CctvSource.create(caseId: 'c1', name: '입구');
      final original = TimelineEvent.create(
        caseId: 'c1',
        source: source,
        displayedAt: DateTime(2026, 10, 8, 15, 0, 0),
        memo: '메모',
      );
      final restored = TimelineEvent.fromMap(original.toMap());
      expect(restored.memo, '메모');
      expect(
        restored.correctedAt.isAtSameMomentAs(original.correctedAt),
        isTrue,
      );
      expect(
        restored.displayedAt.isAtSameMomentAs(original.displayedAt),
        isTrue,
      );
    });
  });
}
