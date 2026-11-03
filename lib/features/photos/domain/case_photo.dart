import '../../../core/services/time_calc_service.dart';

/// 사진 종류 (#28).
enum CasePhotoKind {
  /// 기준 촬영(실제시간 화면/CCTV LIVE 화면).
  baseline('기준'),

  /// 녹화장면 캡처.
  scene('장면'),

  /// 그 밖의 참고 사진.
  other('기타');

  const CasePhotoKind(this.label);

  final String label;

  static CasePhotoKind fromName(String? name) {
    for (final value in CasePhotoKind.values) {
      if (value.name == name) return value;
    }
    return CasePhotoKind.other;
  }
}

/// 사건·CCTV별 사진 보관함 모델 (#28). 불변.
///
/// 파일은 [PhotoStorageService]가 관리하는 상대 경로만 저장하고,
/// 보정 실제시간은 촬영 시점의 CCTV 오프셋으로 확정한다.
class CasePhoto {
  final String id;
  final String caseId;
  final String sourceId;
  final CasePhotoKind kind;

  /// 보관 폴더 기준 상대 경로 (또는 기존 절대 경로).
  final String filePath;

  /// 사진을 촬영·추가한 시각.
  final DateTime capturedAt;

  /// 사진에 표시된 CCTV 시각 (없으면 null).
  final DateTime? displayedAt;

  /// 촬영 시점의 CCTV 오프셋 (ms, 없으면 null).
  final int? offsetMillis;

  /// 보정 실제시간 (표시시각 + 오프셋, 계산 불가하면 null).
  final DateTime? correctedAt;

  final String memo;
  final DateTime createdAt;

  const CasePhoto({
    required this.id,
    required this.caseId,
    required this.sourceId,
    required this.kind,
    required this.filePath,
    required this.capturedAt,
    this.displayedAt,
    this.offsetMillis,
    this.correctedAt,
    this.memo = '',
    required this.createdAt,
  });

  factory CasePhoto.create({
    required String caseId,
    required String sourceId,
    required String filePath,
    CasePhotoKind kind = CasePhotoKind.scene,
    DateTime? capturedAt,
    DateTime? displayedAt,
    int? offsetMillis,
    String memo = '',
  }) {
    final now = capturedAt ?? DateTime.now();
    DateTime? corrected;
    if (displayedAt != null && offsetMillis != null) {
      corrected = TimeCalcService.correctedAt(
        displayedAt: displayedAt,
        offsetMillis: offsetMillis,
      );
    }
    return CasePhoto(
      id: now.microsecondsSinceEpoch.toString(),
      caseId: caseId,
      sourceId: sourceId,
      kind: kind,
      filePath: filePath,
      capturedAt: now,
      displayedAt: displayedAt,
      offsetMillis: offsetMillis,
      correctedAt: corrected,
      memo: memo,
      createdAt: now,
    );
  }

  /// 정렬 기준 시각: 보정 실제시간 우선, 없으면 촬영 시각.
  DateTime get sortAt => correctedAt ?? capturedAt;

  factory CasePhoto.fromMap(Map<String, dynamic> map) {
    DateTime? parseNullable(Object? value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value)?.toLocal();
    }

    final capturedAt = parseNullable(map['capturedAt']) ?? DateTime.now();
    final displayedAt = parseNullable(map['displayedAt']);
    final rawOffset = map['offsetMillis'];
    final offsetMillis = rawOffset is int
        ? rawOffset
        : int.tryParse('${rawOffset ?? ''}');
    final correctedAt = parseNullable(map['correctedAt']);

    return CasePhoto(
      id: (map['id'] ?? '') as String,
      caseId: (map['caseId'] ?? '') as String,
      sourceId: (map['sourceId'] ?? '') as String,
      kind: CasePhotoKind.fromName(map['kind'] as String?),
      filePath: (map['filePath'] ?? '') as String,
      capturedAt: capturedAt,
      displayedAt: displayedAt,
      offsetMillis: offsetMillis,
      correctedAt: correctedAt,
      memo: (map['memo'] ?? '') as String,
      createdAt: parseNullable(map['createdAt']) ?? capturedAt,
    );
  }

  Map<String, dynamic> toMap() {
    String? iso(DateTime? v) => v?.toUtc().toIso8601String();
    return {
      'id': id,
      'caseId': caseId,
      'sourceId': sourceId,
      'kind': kind.name,
      'filePath': filePath,
      'capturedAt': iso(capturedAt),
      'displayedAt': iso(displayedAt),
      'offsetMillis': offsetMillis,
      'correctedAt': iso(correctedAt),
      'memo': memo,
      'createdAt': iso(createdAt),
    };
  }

  CasePhoto copyWith({
    CasePhotoKind? kind,
    String? filePath,
    String? memo,
    DateTime? Function()? displayedAt,
    int? Function()? offsetMillis,
  }) {
    final nextDisplayed = displayedAt != null
        ? displayedAt()
        : this.displayedAt;
    final nextOffset = offsetMillis != null
        ? offsetMillis()
        : this.offsetMillis;
    DateTime? nextCorrected = correctedAt;
    if (nextDisplayed != null && nextOffset != null) {
      nextCorrected = TimeCalcService.correctedAt(
        displayedAt: nextDisplayed,
        offsetMillis: nextOffset,
      );
    } else if (nextDisplayed == null) {
      nextCorrected = null;
    }
    return CasePhoto(
      id: id,
      caseId: caseId,
      sourceId: sourceId,
      kind: kind ?? this.kind,
      filePath: filePath ?? this.filePath,
      capturedAt: capturedAt,
      displayedAt: nextDisplayed,
      offsetMillis: nextOffset,
      correctedAt: nextCorrected,
      memo: memo ?? this.memo,
      createdAt: createdAt,
    );
  }
}
