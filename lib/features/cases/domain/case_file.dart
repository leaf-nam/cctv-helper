/// 사건(케이스) 도메인 모델. 불변.
class CaseFile {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;

  const CaseFile({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
  });

  factory CaseFile.create({required String title, String description = ''}) {
    final now = DateTime.now();
    return CaseFile(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      description: description,
      createdAt: now,
    );
  }

  factory CaseFile.fromMap(Map<String, dynamic> map) {
    return CaseFile(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
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
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  CaseFile copyWith({String? title, String? description}) {
    return CaseFile(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}
