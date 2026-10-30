import '../../events/domain/timeline_event.dart';
import '../../photos/domain/case_photo.dart';

/// 통합 타임라인 항목 (#7).
///
/// 기록([TimelineEvent])과 사진([CasePhoto])을 보정된 실제시간 기준으로
/// 한 목록에 섞어 표시하기 위한 표시 모델이다.
class TimelineEntry {
  const TimelineEntry({
    required this.id,
    required this.sourceId,
    required this.at,
    required this.isPhoto,
    this.displayedAt,
    this.offsetMillis,
    this.memo = '',
    this.photoPaths = const [],
    this.kindLabel = '',
  });

  final String id;
  final String sourceId;

  /// 보정된 실제시간 (사진에 보정값이 없으면 촬영 시각).
  final DateTime at;

  /// 영상/사진에 표시된 CCTV 시각.
  final DateTime? displayedAt;

  /// 보정에 사용한 CCTV 오프셋 (ms).
  final int? offsetMillis;

  final String memo;

  /// 사진 경로 목록 (기록은 첨부 사진, 사진 항목은 1장).
  final List<String> photoPaths;

  /// `기록`, `장면`, `기준` 등 종류 라벨.
  final String kindLabel;

  final bool isPhoto;

  /// 기록·사진을 합쳐 보정시각 오름차순으로 정렬한다.
  static List<TimelineEntry> build({
    required List<TimelineEvent> events,
    required List<CasePhoto> photos,
  }) {
    final list = <TimelineEntry>[
      for (final event in events)
        TimelineEntry(
          id: event.id,
          sourceId: event.sourceId,
          at: event.correctedAt,
          isPhoto: false,
          displayedAt: event.displayedAt,
          offsetMillis: event.correctedAt
              .difference(event.displayedAt)
              .inMilliseconds,
          memo: event.memo,
          photoPaths: event.photoPaths,
          kindLabel: '기록',
        ),
      for (final photo in photos)
        TimelineEntry(
          id: photo.id,
          sourceId: photo.sourceId,
          at: photo.correctedAt ?? photo.capturedAt,
          isPhoto: true,
          displayedAt: photo.displayedAt,
          offsetMillis: photo.offsetMillis,
          memo: photo.memo,
          photoPaths: photo.filePath.isEmpty ? const [] : [photo.filePath],
          kindLabel: photo.kind.label,
        ),
    ];
    list.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
    return list;
  }
}
