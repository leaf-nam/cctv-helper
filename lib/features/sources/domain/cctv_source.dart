import '../../../core/services/time_calc_service.dart';

/// CCTV 원천 도메인 모델. 불변.
///
/// 시간 규약: `offsetMillis = actualAt - displayedAt` (ms),
/// `보정시각 = displayedAt + offsetMillis`.
class CctvSource {
  final String id;
  final String caseId;
  final String name;

  /// 사건 내 순서 (reorder, #4)
  final int sortOrder;

  /// 사용자가 고른 테마 색상 인덱스 (#43). null이면 목록 순서로 기본 배정.
  final int? colorIndex;

  /// CCTV 영상에 표시된 시각 (미입력 허용).
  final DateTime? displayedAt;

  /// 같은 순간의 실제 현재시간 (미입력 허용).
  final DateTime? actualAt;
  final DateTime createdAt;

  const CctvSource({
    required this.id,
    required this.caseId,
    required this.name,
    this.sortOrder = 0,
    this.colorIndex,
    this.displayedAt,
    this.actualAt,
    required this.createdAt,
  });

  factory CctvSource.create({
    required String caseId,
    required String name,
    int sortOrder = 0,
    int? colorIndex,
  }) {
    final now = DateTime.now();
    return CctvSource(
      id: now.microsecondsSinceEpoch.toString(),
      caseId: caseId,
      name: name,
      sortOrder: sortOrder,
      colorIndex: colorIndex,
      createdAt: now,
    );
  }

  /// 오차 (ms). 시각 둘 중 하나라도 없으면 null.
  int? get offsetMillis {
    if (displayedAt == null || actualAt == null) return null;
    return TimeCalcService.offsetMillis(
      displayedAt: displayedAt!,
      actualAt: actualAt!,
    );
  }

  /// 표시시각을 오프셋으로 보정한 시각. 계산 불가하면 null.
  DateTime? correct(DateTime target) {
    final offset = offsetMillis;
    if (offset == null) return null;
    return TimeCalcService.correctedAt(
      displayedAt: target,
      offsetMillis: offset,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String)?.toLocal();
  }

  factory CctvSource.fromMap(Map<String, dynamic> map) {
    return CctvSource(
      id: (map['id'] ?? '') as String,
      caseId: (map['caseId'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      sortOrder: (map['sortOrder'] ?? 0) as int,
      colorIndex: (map['colorIndex'] as num?)?.toInt(),
      displayedAt: _parseDate(map['displayedAt']),
      actualAt: _parseDate(map['actualAt']),
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '') as String)?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'caseId': caseId,
      'name': name,
      'sortOrder': sortOrder,
      'colorIndex': colorIndex,
      'displayedAt': displayedAt?.toUtc().toIso8601String(),
      'actualAt': actualAt?.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  CctvSource copyWith({
    String? name,
    int? sortOrder,
    int? Function()? colorIndex,
    DateTime? Function()? displayedAt,
    DateTime? Function()? actualAt,
  }) {
    return CctvSource(
      id: id,
      caseId: caseId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      colorIndex: colorIndex != null ? colorIndex() : this.colorIndex,
      displayedAt: displayedAt != null ? displayedAt() : this.displayedAt,
      actualAt: actualAt != null ? actualAt() : this.actualAt,
      createdAt: createdAt,
    );
  }
}
