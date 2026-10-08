import 'package:flutter/foundation.dart';

import '../data/cctv_source_repository.dart';
import '../domain/cctv_source.dart';

/// 사건별 CCTV 목록 상태 관리.
class SourcesProvider extends ChangeNotifier {
  final CctvSourceRepository _repo;

  SourcesProvider([CctvSourceRepository? repo])
    : _repo = repo ?? InMemoryCctvSourceRepository();

  List<CctvSource> byCase(String caseId) => _repo.getByCase(caseId);

  CctvSource? getById(String id) => _repo.getById(id);

  Future<void> addSource(String caseId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final order = _repo.getByCase(caseId).length;
    // 실제 시각은 현재시간으로 초기화 (#1). CCTV 시각은 영상 확인 후 입력.
    final now = DateTime.now();
    await _repo.add(
      CctvSource(
        id: now.microsecondsSinceEpoch.toString(),
        caseId: caseId,
        name: trimmed,
        sortOrder: order,
        actualAt: now,
        createdAt: now,
      ),
    );
    notifyListeners();
  }

  Future<void> renameSource(String id, String name) async {
    final found = _repo.getById(id);
    final trimmed = name.trim();
    if (found == null || trimmed.isEmpty) return;
    await _repo.update(found.copyWith(name: trimmed));
    notifyListeners();
  }

  /// CCTV 표시시각·실제시각 입력 (#1). 오프셋은 getter로 자동 계산 (#2).
  Future<void> updateTimes(
    String id, {
    DateTime? Function()? displayedAt,
    DateTime? Function()? actualAt,
  }) async {
    final found = _repo.getById(id);
    if (found == null) return;
    await _repo.update(
      found.copyWith(displayedAt: displayedAt, actualAt: actualAt),
    );
    notifyListeners();
  }

  Future<void> reorder(String caseId, int oldIndex, int newIndex) async {
    // newIndex는 최종 위치 (호출자가 조정済 — ReorderableListView.onReorderItem 규약).
    final list = _repo.getByCase(caseId);
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
    notifyListeners();
  }

  Future<void> removeSource(String id) async {
    await _repo.remove(id);
    notifyListeners();
  }
}
