import '../domain/timeline_event.dart';

/// 사건 기록 저장소 추상.
abstract class TimelineEventRepository {
  List<TimelineEvent> getByCase(String caseId);
  List<TimelineEvent> getBySource(String sourceId);
  TimelineEvent? getById(String id);
  Future<void> add(TimelineEvent item);
  Future<void> update(TimelineEvent item);
  Future<void> remove(String id);
}

/// 메모리 구현체. 사건별 조회는 보정시각 오름차순 정렬.
class InMemoryTimelineEventRepository implements TimelineEventRepository {
  final Map<String, TimelineEvent> _store = {};

  @override
  List<TimelineEvent> getByCase(String caseId) {
    final list = _store.values.where((e) => e.caseId == caseId).toList()
      ..sort((a, b) => a.correctedAt.compareTo(b.correctedAt));
    return list;
  }

  @override
  List<TimelineEvent> getBySource(String sourceId) {
    final list = _store.values.where((e) => e.sourceId == sourceId).toList()
      ..sort((a, b) => a.correctedAt.compareTo(b.correctedAt));
    return list;
  }

  @override
  TimelineEvent? getById(String id) => _store[id];

  @override
  Future<void> add(TimelineEvent item) async {
    _store[item.id] = item;
  }

  @override
  Future<void> update(TimelineEvent item) async {
    if (_store.containsKey(item.id)) {
      _store[item.id] = item;
    }
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
  }
}
