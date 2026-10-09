import '../domain/cctv_source.dart';

/// CCTV 원천 저장소 추상.
abstract class CctvSourceRepository {
  List<CctvSource> getAll();
  List<CctvSource> getByCase(String caseId);
  CctvSource? getById(String id);
  Future<void> add(CctvSource item);
  Future<void> update(CctvSource item);
  Future<void> remove(String id);
  Future<void> importAll(List<CctvSource> items);
}

/// 메모리 구현체.
class InMemoryCctvSourceRepository implements CctvSourceRepository {
  final Map<String, CctvSource> _store = {};

  @override
  List<CctvSource> getAll() => _store.values.toList();

  @override
  List<CctvSource> getByCase(String caseId) {
    final list = _store.values.where((e) => e.caseId == caseId).toList()
      ..sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.createdAt.compareTo(b.createdAt);
      });
    return list;
  }

  @override
  CctvSource? getById(String id) => _store[id];

  @override
  Future<void> add(CctvSource item) async {
    _store[item.id] = item;
  }

  @override
  Future<void> update(CctvSource item) async {
    if (_store.containsKey(item.id)) {
      _store[item.id] = item;
    }
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> importAll(List<CctvSource> items) async {
    _store
      ..clear()
      ..addEntries(items.map((e) => MapEntry(e.id, e)));
  }
}
