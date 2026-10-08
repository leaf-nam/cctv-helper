import 'package:flutter/foundation.dart';

import '../../sources/domain/cctv_source.dart';
import '../data/timeline_event_repository.dart';
import '../domain/timeline_event.dart';

/// 사건 기록 상태 관리.
class EventsProvider extends ChangeNotifier {
  final TimelineEventRepository _repo;

  EventsProvider([TimelineEventRepository? repo])
    : _repo = repo ?? InMemoryTimelineEventRepository();

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
    notifyListeners();
  }

  Future<void> updateMemo(String id, String memo) async {
    final found = _repo.getById(id);
    if (found == null) return;
    await _repo.update(found.copyWith(memo: memo.trim()));
    notifyListeners();
  }

  Future<void> removeEvent(String id) async {
    await _repo.remove(id);
    notifyListeners();
  }
}
