/// 사건(케이스) 도메인 모델. 불변.
class CaseFile {
  final String id;
  final String title;
  final String description;

  /// 사건 목록 순서 (reorder용).
  final int sortOrder;
  final DateTime createdAt;

  const CaseFile({
    required this.id,
    required this.title,
    this.description = '',
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory CaseFile.create({
    required String title,
    String description = '',
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return CaseFile(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      description: description,
      sortOrder: sortOrder,
      createdAt: now,
    );
  }

  factory CaseFile.fromMap(Map<String, dynamic> map) {
    return CaseFile(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      sortOrder: (map['sortOrder'] ?? 0) as int,
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '') as String) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  CaseFile copyWith({String? title, String? description, int? sortOrder}) {
    return CaseFile(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }
}
