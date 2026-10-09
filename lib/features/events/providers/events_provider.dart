import 'package:flutter/foundation.dart';

import '../../../core/constants/store_keys.dart';
import '../../../core/services/local_store.dart';
import '../../sources/domain/cctv_source.dart';
import '../data/timeline_event_repository.dart';
import '../domain/timeline_event.dart';

/// 사건 기록 상태 관리 (로컬 저장 연동).
class EventsProvider extends ChangeNotifier {
  final TimelineEventRepository _repo;
  final LocalStore? _store;

  EventsProvider([TimelineEventRepository? repo, LocalStore? store])
    : _repo = repo ?? InMemoryTimelineEventRepository(),
      _store = store;

  /// 시작 시 로컬 저장분 복원.
  Future<void> load() async {
    final store = _store;
    if (store == null) return;
    final docs = store.loadAll(StoreKeys.events);
    await _repo.importAll(docs.map(TimelineEvent.fromMap).toList());
    notifyListeners();
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) return;
    await store.saveAll(
      StoreKeys.events,
      _repo.getAll().map((e) => e.toMap()).toList(),
    );
  }

  List<TimelineEvent> byCase(String caseId) => _repo.getByCase(caseId);

  List<TimelineEvent> bySource(String sourceId) =>
      _repo.getBySource(sourceId);

  Future<void> addEvent({
    required String caseId,
    required CctvSource source,
    required DateTime displayedAt,
    String memo = '',
    String photoPath = '',
  }) async {
    await _repo.add(
      TimelineEvent.create(
        caseId: caseId,
        source: source,
        displayedAt: displayedAt,
        memo: memo.trim(),
        photoPath: photoPath.trim(),
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> updateMemo(String id, String memo) async {
    final found = _repo.getById(id);
    if (found == null) return;
    await _repo.update(found.copyWith(memo: memo.trim()));
    await _persist();
    notifyListeners();
  }

  Future<void> removeEvent(String id) async {
    await _repo.remove(id);
    await _persist();
    notifyListeners();
  }
}
