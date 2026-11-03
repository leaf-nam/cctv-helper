import '../domain/case_photo.dart';

/// 사진 보관함 저장소 추상 (#28).
abstract class CasePhotoRepository {
  List<CasePhoto> getAll();
  List<CasePhoto> getByCase(String caseId);
  List<CasePhoto> getBySource(String sourceId);
  CasePhoto? getById(String id);
  Future<void> add(CasePhoto item);
  Future<void> update(CasePhoto item);
  Future<void> remove(String id);
  Future<void> removeByCase(String caseId);
  Future<void> removeBySource(String sourceId);
  Future<void> importAll(List<CasePhoto> items);
}

/// 메모리 구현체. 사건별 조회는 보정 실제시간 오름차순 정렬.
class InMemoryCasePhotoRepository implements CasePhotoRepository {
  final Map<String, CasePhoto> _store = {};

  @override
  List<CasePhoto> getAll() => _store.values.toList();

  @override
  List<CasePhoto> getByCase(String caseId) {
    final list = _store.values.where((e) => e.caseId == caseId).toList()
      ..sort((a, b) => a.sortAt.compareTo(b.sortAt));
    return list;
  }

  @override
  List<CasePhoto> getBySource(String sourceId) {
    final list = _store.values.where((e) => e.sourceId == sourceId).toList()
      ..sort((a, b) => a.sortAt.compareTo(b.sortAt));
    return list;
  }

  @override
  CasePhoto? getById(String id) => _store[id];

  @override
  Future<void> add(CasePhoto item) async {
    _store[item.id] = item;
  }

  @override
  Future<void> update(CasePhoto item) async {
    if (_store.containsKey(item.id)) {
      _store[item.id] = item;
    }
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> removeByCase(String caseId) async {
    _store.removeWhere((_, value) => value.caseId == caseId);
  }

  @override
  Future<void> removeBySource(String sourceId) async {
    _store.removeWhere((_, value) => value.sourceId == sourceId);
  }

  @override
  Future<void> importAll(List<CasePhoto> items) async {
    _store
      ..clear()
      ..addEntries(items.map((e) => MapEntry(e.id, e)));
  }
}
