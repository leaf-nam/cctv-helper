import 'package:cctv_helper/features/events/domain/timeline_event.dart';
import 'package:cctv_helper/features/photos/domain/case_photo.dart';
import 'package:cctv_helper/features/sources/domain/cctv_source.dart';
import 'package:cctv_helper/features/timeline/domain/timeline_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = CctvSource.create(caseId: 'c1', name: '입구').copyWith(
    displayedAt: () => DateTime(2026, 10, 22, 14),
    actualAt: () => DateTime(2026, 10, 22, 14, 2),
  );

  test('기록과 사진을 보정시각 오름차순으로 합친다', () {
    final event = TimelineEvent.create(
      caseId: 'c1',
      source: source,
      displayedAt: DateTime(2026, 10, 22, 15),
      memo: '기록',
      photoPaths: const ['e.jpg'],
    );
    final photo = CasePhoto.create(
      caseId: 'c1',
      sourceId: source.id,
      filePath: 'p.jpg',
      displayedAt: DateTime(2026, 10, 22, 14, 30),
      offsetMillis: 120000,
      memo: '사진',
    );

    final entries = TimelineEntry.build(events: [event], photos: [photo]);
    expect(entries.length, 2);
    expect(entries.first.isPhoto, isTrue);
    expect(entries.first.at, DateTime(2026, 10, 22, 14, 32));
    expect(entries.first.kindLabel, '장면');
    expect(entries.first.photoPaths, ['p.jpg']);
    expect(entries.last.isPhoto, isFalse);
    expect(entries.last.memo, '기록');
    expect(entries.last.at, DateTime(2026, 10, 22, 15, 2));
    expect(entries.last.offsetMillis, 120000);
    expect(entries.last.photoPaths, ['e.jpg']);
  });

  test('보정시각이 같으면 id로 안정 정렬', () {
    final event = TimelineEvent.create(
      caseId: 'c1',
      source: source,
      displayedAt: DateTime(2026, 10, 22, 15),
    );
    final photo = CasePhoto.create(
      caseId: 'c1',
      sourceId: source.id,
      filePath: '',
      displayedAt: DateTime(2026, 10, 22, 15),
      offsetMillis: 120000,
    );
    final entries = TimelineEntry.build(events: [event], photos: [photo]);
    expect(entries.length, 2);
    expect(entries[0].id.compareTo(entries[1].id) <= 0, isTrue);
  });
}
