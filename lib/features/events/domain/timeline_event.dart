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

  /// 사진 파일 경로 목록 (상대 경로, 없으면 빈 목록).
  ///
  /// 1.1.0부터 여러 장을 보관한다. 기존 데이터의 단일 `photoPath`는
  /// [fromMap]에서 목록으로 승격한다.
  final List<String> photoPaths;

  /// 첫 번째 사진 경로 (기존 UI 호환용, 없으면 빈 문자열).
  String get photoPath => photoPaths.isEmpty ? '' : photoPaths.first;

  final DateTime createdAt;

  const TimelineEvent({
    required this.id,
    required this.caseId,
    required this.sourceId,
    required this.displayedAt,
    required this.correctedAt,
    this.memo = '',
    this.photoPaths = const [],
    required this.createdAt,
  });

  /// CCTV 오프셋으로부터 보정시각을 확정해 생성.
  factory TimelineEvent.create({
    required String caseId,
    required CctvSource source,
    required DateTime displayedAt,
    String memo = '',
    String photoPath = '',
    List<String> photoPaths = const [],
  }) {
    final now = DateTime.now();
    final offset = source.offsetMillis ?? 0;
    final paths = _mergePaths(photoPath, photoPaths);
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
      photoPaths: paths,
      createdAt: now,
    );
  }

  static List<String> _mergePaths(String single, List<String> many) {
    if (many.isNotEmpty) return List<String>.unmodifiable(many);
    if (single.trim().isEmpty) return const [];
    return List<String>.unmodifiable([single.trim()]);
  }

  factory TimelineEvent.fromMap(Map<String, dynamic> map) {
    DateTime parse(String key) =>
        DateTime.tryParse((map[key] ?? '') as String)?.toLocal() ??
        DateTime.now();
    final many = (map['photoPaths'] as List?)
        ?.whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
    final paths = (many == null || many.isEmpty)
        ? _mergePaths((map['photoPath'] ?? '') as String, const [])
        : List<String>.unmodifiable(many);
    return TimelineEvent(
      id: (map['id'] ?? '') as String,
      caseId: (map['caseId'] ?? '') as String,
      sourceId: (map['sourceId'] ?? '') as String,
      displayedAt: parse('displayedAt'),
      correctedAt: parse('correctedAt'),
      memo: (map['memo'] ?? '') as String,
      photoPaths: paths,
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
      // 기존 버전 호환: 단일 경로도 함께 기록한다.
      'photoPath': photoPath,
      'photoPaths': photoPaths,
      'createdAt': iso(createdAt),
    };
  }

  TimelineEvent copyWith({
    String? memo,
    String? photoPath,
    List<String>? photoPaths,
  }) {
    return TimelineEvent(
      id: id,
      caseId: caseId,
      sourceId: sourceId,
      displayedAt: displayedAt,
      correctedAt: correctedAt,
      memo: memo ?? this.memo,
      photoPaths: photoPaths != null
          ? List<String>.unmodifiable(photoPaths)
          : photoPath != null
          ? _mergePaths(photoPath, const [])
          : this.photoPaths,
      createdAt: createdAt,
    );
  }
}
