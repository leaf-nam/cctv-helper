import '../domain/case_file.dart';

/// 사건 저장소 추상.
abstract class CaseRepository {
  List<CaseFile> getAll();
  CaseFile? getById(String id);
  Future<void> add(CaseFile item);
  Future<void> update(CaseFile item);
  Future<void> remove(String id);
  Future<void> importAll(List<CaseFile> items);
}

/// 메모리 구현체.
class InMemoryCaseRepository implements CaseRepository {
  final Map<String, CaseFile> _store = {};

  @override
  List<CaseFile> getAll() {
    final list = _store.values.toList()
      ..sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return b.createdAt.compareTo(a.createdAt);
      });
    return list;
  }

  @override
  CaseFile? getById(String id) => _store[id];

  @override
  Future<void> add(CaseFile item) async {
    _store[item.id] = item;
  }

  @override
  Future<void> update(CaseFile item) async {
    if (_store.containsKey(item.id)) {
      _store[item.id] = item;
    }
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> importAll(List<CaseFile> items) async {
    _store
      ..clear()
      ..addEntries(items.map((e) => MapEntry(e.id, e)));
  }
}
