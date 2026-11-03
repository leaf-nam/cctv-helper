import 'package:cctv_helper/features/events/domain/timeline_event.dart';
import 'package:cctv_helper/features/photos/domain/case_photo.dart';
import 'package:cctv_helper/features/sources/domain/cctv_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CasePhoto', () {
    test('표시시각+오프셋으로 보정 실제시간 확정', () {
      final photo = CasePhoto.create(
        caseId: 'c1',
        sourceId: 's1',
        filePath: 'cases/c1/sources/s1/a.jpg',
        kind: CasePhotoKind.scene,
        displayedAt: DateTime(2026, 10, 22, 14, 0, 0),
        offsetMillis: 120000,
        memo: '장면',
      );
      expect(photo.correctedAt, DateTime(2026, 10, 22, 14, 2, 0));
      expect(photo.sortAt, photo.correctedAt);
      expect(photo.kind, CasePhotoKind.scene);
    });

    test('오프셋이 없으면 보정 실제시간 null', () {
      final photo = CasePhoto.create(
        caseId: 'c1',
        sourceId: 's1',
        filePath: '',
        displayedAt: DateTime(2026, 10, 22, 14, 0, 0),
      );
      expect(photo.correctedAt, isNull);
      expect(photo.sortAt, photo.capturedAt);
    });

    test('fromMap/toMap 라운드트립', () {
      final original = CasePhoto.create(
        caseId: 'c1',
        sourceId: 's1',
        filePath: 'cases/c1/sources/s1/a.jpg',
        kind: CasePhotoKind.baseline,
        displayedAt: DateTime(2026, 10, 22, 14, 0, 0),
        offsetMillis: 120000,
        memo: '기준',
      );
      final restored = CasePhoto.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.kind, CasePhotoKind.baseline);
      expect(restored.displayedAt!.isUtc, isFalse);
      expect(
        restored.correctedAt!.isAtSameMomentAs(original.correctedAt!),
        isTrue,
      );
      expect(restored.offsetMillis, 120000);
      expect(restored.memo, '기준');
    });

    test('알 수 없는 kind는 기타로 복원', () {
      final map = CasePhoto.create(
        caseId: 'c1',
        sourceId: 's1',
        filePath: 'x',
      ).toMap();
      map['kind'] = 'unknown';
      expect(CasePhoto.fromMap(map).kind, CasePhotoKind.other);
    });

    test('메모 수정 시 보정 시간 유지', () {
      final photo = CasePhoto.create(
        caseId: 'c1',
        sourceId: 's1',
        filePath: 'x',
        displayedAt: DateTime(2026, 10, 22, 14, 0, 0),
        offsetMillis: 120000,
      );
      final updated = photo.copyWith(memo: '수정');
      expect(updated.memo, '수정');
      expect(updated.correctedAt, photo.correctedAt);
    });
  });

  group('TimelineEvent photoPaths 호환', () {
    final source = CctvSource.create(caseId: 'c1', name: '입구');

    test('기존 단일 photoPath 데이터를 목록으로 읽기', () {
      final event = TimelineEvent.create(
        caseId: 'c1',
        source: source,
        displayedAt: DateTime(2026, 10, 8, 15),
        photoPath: '/tmp/old.jpg',
      );
      expect(event.photoPaths, ['/tmp/old.jpg']);
      expect(event.photoPath, '/tmp/old.jpg');

      final legacyMap = event.toMap()..remove('photoPaths');
      final restored = TimelineEvent.fromMap(legacyMap);
      expect(restored.photoPaths, ['/tmp/old.jpg']);
      expect(restored.photoPath, '/tmp/old.jpg');
    });

    test('여러 장 저장·복원', () {
      final event = TimelineEvent.create(
        caseId: 'c1',
        source: source,
        displayedAt: DateTime(2026, 10, 8, 15),
        photoPaths: const ['a.jpg', 'b.jpg'],
      );
      expect(event.photoPaths, ['a.jpg', 'b.jpg']);
      final restored = TimelineEvent.fromMap(event.toMap());
      expect(restored.photoPaths, ['a.jpg', 'b.jpg']);
      expect(restored.toMap()['photoPath'], 'a.jpg');
    });

    test('copyWith로 사진 목록 교체', () {
      final event = TimelineEvent.create(
        caseId: 'c1',
        source: source,
        displayedAt: DateTime(2026, 10, 8, 15),
        photoPaths: const ['a.jpg'],
      );
      expect(event.copyWith(photoPaths: const []).photoPaths, isEmpty);
      expect(event.copyWith(photoPath: 'b.jpg').photoPaths, ['b.jpg']);
    });
  });
}
