import 'dart:io';

import 'package:cctv_helper/core/services/local_store.dart';
import 'package:cctv_helper/core/services/photo_storage_service.dart';
import 'package:cctv_helper/features/events/domain/timeline_event.dart';
import 'package:cctv_helper/features/events/providers/events_provider.dart';
import 'package:cctv_helper/features/photos/domain/case_photo.dart';
import 'package:cctv_helper/features/photos/providers/photos_provider.dart';
import 'package:cctv_helper/features/sources/domain/cctv_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temp;
  late PhotoStorageService storage;
  late File picked;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cctv_photos_provider_');
    storage = PhotoStorageService(Directory(temp.path));
    picked = File('${temp.path}/pick.jpg')..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
    PhotoStorageService.instance = null;
  });

  test('사진 추가 시 보관 폴더로 복사하고 보정시각 순 정렬', () async {
    final provider = PhotosProvider(null, null, storage);
    final first = await provider.addPhoto(
      caseId: 'c1',
      sourceId: 's1',
      filePath: picked.path,
      displayedAt: DateTime(2026, 10, 22, 14),
      offsetMillis: 120000,
    );
    final second = await provider.addPhoto(
      caseId: 'c1',
      sourceId: 's1',
      filePath: picked.path,
      displayedAt: DateTime(2026, 10, 22, 13),
      offsetMillis: 120000,
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.filePath, startsWith('cases/c1/sources/s1/'));
    expect(File(storage.resolvePath(first.filePath)).existsSync(), isTrue);

    final list = provider.byCase('c1');
    expect(list.length, 2);
    expect(list.first.id, second!.id, reason: '보정 실제시간 오름차순');
  });

  test('메모 수정·사진 삭제 시 파일도 삭제', () async {
    final provider = PhotosProvider(null, null, storage);
    final photo = await provider.addPhoto(
      caseId: 'c1',
      sourceId: 's1',
      filePath: picked.path,
    );
    await provider.updateMemo(photo!.id, '  메모  ');
    expect(provider.getById(photo.id)!.memo, '메모');

    final path = storage.resolvePath(photo.filePath);
    expect(File(path).existsSync(), isTrue);
    await provider.removePhoto(photo.id);
    expect(provider.getById(photo.id), isNull);
    expect(File(path).existsSync(), isFalse);
  });

  test('CCTV/사건 단위 정리', () async {
    final provider = PhotosProvider(null, null, storage);
    await provider.addPhoto(
      caseId: 'c1',
      sourceId: 's1',
      filePath: picked.path,
    );
    await provider.addPhoto(
      caseId: 'c1',
      sourceId: 's2',
      filePath: picked.path,
    );
    await provider.addPhoto(
      caseId: 'c2',
      sourceId: 's3',
      filePath: picked.path,
    );

    await provider.removeBySource('s1');
    expect(provider.byCase('c1').every((e) => e.sourceId == 's2'), isTrue);

    await provider.removeByCase('c1');
    expect(provider.byCase('c1'), isEmpty);
    expect(provider.byCase('c2').length, 1);
  });

  test('로컬 저장·복원', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);

    final writer = PhotosProvider(null, store, storage);
    final added = await writer.addPhoto(
      caseId: 'c1',
      sourceId: 's1',
      filePath: picked.path,
      kind: CasePhotoKind.scene,
      memo: '저장',
    );

    final reader = PhotosProvider(null, store, storage);
    await reader.load();
    expect(reader.byCase('c1').length, 1);
    expect(reader.byCase('c1').first.id, added!.id);
    expect(reader.byCase('c1').first.memo, '저장');
    expect(reader.byCase('c1').first.filePath, added.filePath);
  });

  test('기존 기록의 절대 경로 사진을 마이그레이션', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    final source = CctvSource.create(caseId: 'c1', name: '입구');
    final legacy = TimelineEvent.create(
      caseId: 'c1',
      source: source,
      displayedAt: DateTime(2026, 10, 22, 14),
      photoPath: picked.path,
    );
    await store.saveAll('events', [legacy.toMap()]);

    final events = EventsProvider(null, store, storage);
    await events.load();
    final loaded = events.byCase('c1').first;
    expect(loaded.filePathOrEmpty, startsWith('cases/c1/sources/'));
    expect(File(storage.resolvePath(loaded.photoPath)).existsSync(), isTrue);
  });

  test('원본이 사라진 기록 사진은 placeholder로 정리', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    final source = CctvSource.create(caseId: 'c1', name: '입구');
    final legacy = TimelineEvent.create(
      caseId: 'c1',
      source: source,
      displayedAt: DateTime(2026, 10, 22, 14),
      photoPath: '${temp.path}/missing.jpg',
    );
    await store.saveAll('events', [legacy.toMap()]);

    final events = EventsProvider(null, store, storage);
    await events.load();
    expect(events.byCase('c1').first.photoPaths, isEmpty);
  });
}

extension on TimelineEvent {
  String get filePathOrEmpty => photoPaths.isEmpty ? '' : photoPaths.first;
}
