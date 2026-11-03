import 'package:flutter/foundation.dart';

import '../../../core/constants/store_keys.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/photo_storage_service.dart';
import '../data/case_photo_repository.dart';
import '../domain/case_photo.dart';

/// 사진 보관함 상태 관리 (로컬 저장 연동, #28).
class PhotosProvider extends ChangeNotifier {
  final CasePhotoRepository _repo;
  final LocalStore? _store;
  final PhotoStorageService? _storage;

  PhotosProvider([
    CasePhotoRepository? repo,
    LocalStore? store,
    PhotoStorageService? storage,
  ]) : _repo = repo ?? InMemoryCasePhotoRepository(),
       _store = store,
       _storage = storage;

  /// 시작 시 로컬 저장분 복원. 기존 절대 경로는 보관 폴더로 마이그레이션한다.
  Future<void> load() async {
    final store = _store;
    if (store == null) return;
    final docs = store.loadAll(StoreKeys.casePhotos);
    var migrated = false;
    final items = <CasePhoto>[];
    for (final doc in docs) {
      var item = CasePhoto.fromMap(doc);
      final storage = _storage;
      if (storage != null && item.filePath.isNotEmpty) {
        final next = await storage.migrateLegacyPath(
          item.filePath,
          caseId: item.caseId,
          sourceId: item.sourceId,
          prefix: item.kind.name,
        );
        if (next != item.filePath) {
          item = item.copyWith(filePath: next);
          migrated = true;
        }
      }
      items.add(item);
    }
    await _repo.importAll(items);
    if (migrated) await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) return;
    await store.saveAll(
      StoreKeys.casePhotos,
      _repo.getAll().map((e) => e.toMap()).toList(),
    );
  }

  List<CasePhoto> byCase(String caseId) => _repo.getByCase(caseId);

  List<CasePhoto> bySource(String sourceId) => _repo.getBySource(sourceId);

  CasePhoto? getById(String id) => _repo.getById(id);

  /// 사건 내 CCTV별 그룹 (CCTV 순서는 [sourceIds] 순서를 따른다).
  Map<String, List<CasePhoto>> groupedBySource(
    String caseId,
    List<String> sourceIds,
  ) {
    final photos = byCase(caseId);
    final result = <String, List<CasePhoto>>{};
    for (final id in sourceIds) {
      final group = photos.where((e) => e.sourceId == id).toList();
      if (group.isNotEmpty) result[id] = group;
    }
    final unknown = photos
        .where((e) => !sourceIds.contains(e.sourceId))
        .toList();
    if (unknown.isNotEmpty) result[''] = unknown;
    return result;
  }

  /// 사진을 보관 폴더로 복사하고 메타데이터를 저장한다.
  Future<CasePhoto?> addPhoto({
    required String caseId,
    required String sourceId,
    required String filePath,
    CasePhotoKind kind = CasePhotoKind.scene,
    DateTime? capturedAt,
    DateTime? displayedAt,
    int? offsetMillis,
    String memo = '',
  }) async {
    var storedPath = filePath.trim();
    final storage = _storage;
    if (storage != null && storedPath.isNotEmpty) {
      final imported = await storage.importFile(
        storedPath,
        caseId: caseId,
        sourceId: sourceId,
        prefix: kind.name,
      );
      // 원본이 사라졌으면 저장하지 않는다.
      if (imported.isEmpty) return null;
      storedPath = imported;
    }
    final photo = CasePhoto.create(
      caseId: caseId,
      sourceId: sourceId,
      filePath: storedPath,
      kind: kind,
      capturedAt: capturedAt,
      displayedAt: displayedAt,
      offsetMillis: offsetMillis,
      memo: memo.trim(),
    );
    await _repo.add(photo);
    await _persist();
    notifyListeners();
    return photo;
  }

  /// 이미 보관 폴더에 있는 사진 레코드를 추가한다.
  Future<void> addExisting(CasePhoto photo) async {
    await _repo.add(photo);
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

  Future<void> removePhoto(String id) async {
    final found = _repo.getById(id);
    if (found == null) return;
    await _storage?.deleteFile(found.filePath);
    await _repo.remove(id);
    await _persist();
    notifyListeners();
  }

  /// CCTV 삭제 시 해당 CCTV 사진을 함께 정리한다.
  Future<void> removeBySource(String sourceId) async {
    final targets = _repo.getBySource(sourceId);
    for (final photo in targets) {
      await _storage?.deleteFile(photo.filePath);
    }
    await _repo.removeBySource(sourceId);
    await _persist();
    notifyListeners();
  }

  /// 사건 삭제 시 사건 사진을 함께 정리한다.
  Future<void> removeByCase(String caseId) async {
    final targets = _repo.getByCase(caseId);
    for (final photo in targets) {
      await _storage?.deleteFile(photo.filePath);
    }
    await _repo.removeByCase(caseId);
    await _persist();
    notifyListeners();
  }
}
