import 'package:flutter/foundation.dart';

import '../../../core/constants/store_keys.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/photo_storage_service.dart';
import '../../sources/domain/cctv_source.dart';
import '../data/timeline_event_repository.dart';
import '../domain/timeline_event.dart';

/// 사건 기록 상태 관리 (로컬 저장 연동).
class EventsProvider extends ChangeNotifier {
  final TimelineEventRepository _repo;
  final LocalStore? _store;
  final PhotoStorageService? _storage;

  EventsProvider([
    TimelineEventRepository? repo,
    LocalStore? store,
    PhotoStorageService? storage,
  ]) : _repo = repo ?? InMemoryTimelineEventRepository(),
       _store = store,
       _storage = storage;

  /// 시작 시 로컬 저장분 복원.
  ///
  /// 기존 절대 경로 사진은 보관 폴더로 복사하고, 원본이 사라진 경로는
  /// placeholder(빈 값)로 정리한다 (#26).
  Future<void> load() async {
    final store = _store;
    if (store == null) return;
    final docs = store.loadAll(StoreKeys.events);
    var migrated = false;
    final items = <TimelineEvent>[];
    for (final doc in docs) {
      var event = TimelineEvent.fromMap(doc);
      final storage = _storage;
      if (storage != null && event.photoPaths.isNotEmpty) {
        final next = <String>[];
        for (final path in event.photoPaths) {
          final stored = await storage.migrateLegacyPath(
            path,
            caseId: event.caseId,
            sourceId: event.sourceId,
            prefix: 'event',
          );
          if (stored.isNotEmpty) next.add(stored);
        }
        if (!listEquals(next, event.photoPaths)) {
          event = event.copyWith(photoPaths: next);
          migrated = true;
        }
      }
      items.add(event);
    }
    await _repo.importAll(items);
    if (migrated) await _persist();
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

  List<TimelineEvent> bySource(String sourceId) => _repo.getBySource(sourceId);

  TimelineEvent? getById(String id) => _repo.getById(id);

  Future<void> addEvent({
    required String caseId,
    required CctvSource source,
    required DateTime displayedAt,
    String memo = '',
    String photoPath = '',
    List<String> photoPaths = const [],
  }) async {
    final candidates = photoPaths.isNotEmpty
        ? photoPaths
        : (photoPath.trim().isEmpty ? <String>[] : [photoPath.trim()]);
    final stored = <String>[];
    for (final path in candidates) {
      final storage = _storage;
      if (storage == null) {
        stored.add(path);
        continue;
      }
      final imported = await storage.importFile(
        path,
        caseId: caseId,
        sourceId: source.id,
        prefix: 'event',
      );
      if (imported.isNotEmpty) stored.add(imported);
    }
    await _repo.add(
      TimelineEvent.create(
        caseId: caseId,
        source: source,
        displayedAt: displayedAt,
        memo: memo.trim(),
        photoPaths: stored,
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
    final found = _repo.getById(id);
    if (found == null) return;
    for (final path in found.photoPaths) {
      await _storage?.deleteFile(path);
    }
    await _repo.remove(id);
    await _persist();
    notifyListeners();
  }

  /// CCTV 삭제 시 해당 CCTV 기록을 정리한다.
  Future<void> removeBySource(String sourceId) async {
    final targets = _repo.getBySource(sourceId);
    for (final event in targets) {
      for (final path in event.photoPaths) {
        await _storage?.deleteFile(path);
      }
      await _repo.remove(event.id);
    }
    await _persist();
    notifyListeners();
  }

  /// 사건 삭제 시 사건 기록을 정리한다.
  Future<void> removeByCase(String caseId) async {
    final targets = _repo.getByCase(caseId);
    for (final event in targets) {
      for (final path in event.photoPaths) {
        await _storage?.deleteFile(path);
      }
      await _repo.remove(event.id);
    }
    await _persist();
    notifyListeners();
  }
}
