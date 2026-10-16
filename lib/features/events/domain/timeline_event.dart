import '../../sources/domain/cctv_source.dart';
import '../../../core/services/time_calc_service.dart';

/// 타임라인 사건(기록·사진) 도메인 모델. 불변.
///
/// `correctedAt = displayedAt + 해당 CCTV의 오프셋`.
/// 사진은 바이너리가 아니라 파일 경로만 저장한다 (1.0.0).
class TimelineEvent {
  final String id;
  final String caseId;
  final String sourceId;

  /// 영상에 표시된 사건 시각.
  final DateTime displayedAt;

  /// 보정시각 (표시 + 오프셋).
  final DateTime correctedAt;
  final String memo;

  /// 사진 파일 경로 (없으면 빈 문자열).
  final String photoPath;
  final DateTime createdAt;

  const TimelineEvent({
    required this.id,
    required this.caseId,
    required this.sourceId,
    required this.displayedAt,
    required this.correctedAt,
    this.memo = '',
    this.photoPath = '',
    required this.createdAt,
  });

  /// CCTV 오프셋으로부터 보정시각을 확정해 생성.
  factory TimelineEvent.create({
    required String caseId,
    required CctvSource source,
    required DateTime displayedAt,
    String memo = '',
    String photoPath = '',
  }) {
    final now = DateTime.now();
    final offset = source.offsetMillis ?? 0;
    return TimelineEvent(
      id: now.microsecondsSinceEpoch.toString(),
      caseId: caseId,
      sourceId: source.id,
      displayedAt: displayedAt,
      correctedAt: TimeCalcService.correctedAt(
        displayedAt: displayedAt,
        offsetMillis: offset,
      ),
      memo: memo,
      photoPath: photoPath,
      createdAt: now,
    );
  }

  factory TimelineEvent.fromMap(Map<String, dynamic> map) {
    DateTime parse(String key) =>
        DateTime.tryParse((map[key] ?? '') as String) ?? DateTime.now();
    return TimelineEvent(
      id: (map['id'] ?? '') as String,
      caseId: (map['caseId'] ?? '') as String,
      sourceId: (map['sourceId'] ?? '') as String,
      displayedAt: parse('displayedAt'),
      correctedAt: parse('correctedAt'),
      memo: (map['memo'] ?? '') as String,
      photoPath: (map['photoPath'] ?? '') as String,
      createdAt: parse('createdAt'),
    );
  }

  Map<String, dynamic> toMap() {
    String iso(DateTime v) => v.toUtc().toIso8601String();
    return {
      'id': id,
      'caseId': caseId,
      'sourceId': sourceId,
      'displayedAt': iso(displayedAt),
      'correctedAt': iso(correctedAt),
      'memo': memo,
      'photoPath': photoPath,
      'createdAt': iso(createdAt),
    };
  }

  TimelineEvent copyWith({String? memo, String? photoPath}) {
    return TimelineEvent(
      id: id,
      caseId: caseId,
      sourceId: sourceId,
      displayedAt: displayedAt,
      correctedAt: correctedAt,
      memo: memo ?? this.memo,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt,
    );
  }
}
