import 'package:flutter/foundation.dart';

import '../data/case_repository.dart';
import '../domain/case_file.dart';

/// 사건 목록 상태 관리.
class CasesProvider extends ChangeNotifier {
  final CaseRepository _repo;

  CasesProvider([CaseRepository? repo])
    : _repo = repo ?? InMemoryCaseRepository();

  List<CaseFile> get cases => _repo.getAll();

  CaseFile? getById(String id) => _repo.getById(id);

  Future<void> addCase(String title, {String description = ''}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _repo.add(
      CaseFile.create(title: trimmed, description: description.trim()),
    );
    notifyListeners();
  }

  Future<void> renameCase(String id, String title) async {
    final found = _repo.getById(id);
    final trimmed = title.trim();
    if (found == null || trimmed.isEmpty) return;
    await _repo.update(found.copyWith(title: trimmed));
    notifyListeners();
  }

  Future<void> removeCase(String id) async {
    await _repo.remove(id);
    notifyListeners();
  }
}
