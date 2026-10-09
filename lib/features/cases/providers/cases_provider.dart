import 'package:flutter/foundation.dart';

import '../../../core/constants/store_keys.dart';
import '../../../core/services/local_store.dart';
import '../data/case_repository.dart';
import '../domain/case_file.dart';

/// 사건 목록 상태 관리 (로컬 저장 연동).
class CasesProvider extends ChangeNotifier {
  final CaseRepository _repo;
  final LocalStore? _store;

  CasesProvider([CaseRepository? repo, LocalStore? store])
    : _repo = repo ?? InMemoryCaseRepository(),
      _store = store;

  /// 시작 시 로컬 저장분 복원.
  Future<void> load() async {
    final store = _store;
    if (store == null) return;
    final docs = store.loadAll(StoreKeys.cases);
    await _repo.importAll(docs.map(CaseFile.fromMap).toList());
    notifyListeners();
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) return;
    await store.saveAll(
      StoreKeys.cases,
      _repo.getAll().map((e) => e.toMap()).toList(),
    );
  }

  List<CaseFile> get cases => _repo.getAll();

  CaseFile? getById(String id) => _repo.getById(id);

  Future<void> addCase(String title, {String description = ''}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _repo.add(
      CaseFile.create(
        title: trimmed,
        description: description.trim(),
        sortOrder: _repo.getAll().length,
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> renameCase(String id, String title) async {
    final found = _repo.getById(id);
    final trimmed = title.trim();
    if (found == null || trimmed.isEmpty) return;
    await _repo.update(found.copyWith(title: trimmed));
    await _persist();
    notifyListeners();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = _repo.getAll();
    if (oldIndex < 0 ||
        oldIndex >= list.length ||
        newIndex < 0 ||
        newIndex >= list.length ||
        oldIndex == newIndex) {
      return;
    }
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    for (var i = 0; i < list.length; i++) {
      await _repo.update(list[i].copyWith(sortOrder: i));
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removeCase(String id) async {
    await _repo.remove(id);
    await _persist();
    notifyListeners();
  }
}
