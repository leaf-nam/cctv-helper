import 'dart:io';

import 'package:cctv_helper/core/services/photo_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory temp;
  late PhotoStorageService storage;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cctv_photo_test_');
    root = Directory('${temp.path}/documents')..createSync(recursive: true);
    storage = PhotoStorageService(root);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
    PhotoStorageService.instance = null;
  });

  test('파일을 cases/<caseId>/sources/<sourceId> 로 복사하고 상대 경로 반환', () async {
    final source = File('${temp.path}/pick.jpg')
      ..writeAsBytesSync([1, 2, 3, 4]);

    final relative = await storage.importFile(
      source.path,
      caseId: 'case1',
      sourceId: 'source1',
    );

    expect(relative, startsWith('cases/case1/sources/source1/'));
    expect(relative.endsWith('.jpg'), isTrue);
    final copied = File(storage.resolvePath(relative));
    expect(copied.existsSync(), isTrue);
    expect(copied.readAsBytesSync(), [1, 2, 3, 4]);
    expect(source.existsSync(), isTrue, reason: '원본은 보존한다');
  });

  test('이미 상대 경로면 그대로 반환', () async {
    final relative = await storage.importFile(
      'cases/a/sources/b/x.jpg',
      caseId: 'a',
      sourceId: 'b',
    );
    expect(relative, 'cases/a/sources/b/x.jpg');
  });

  test('기존 절대 경로 마이그레이션: 파일이 없으면 빈 문자열', () async {
    final missing = await storage.migrateLegacyPath(
      '${temp.path}/missing.jpg',
      caseId: 'c',
      sourceId: 's',
    );
    expect(missing, isEmpty);

    final source = File('${temp.path}/legacy.png')..writeAsBytesSync([9]);
    final migrated = await storage.migrateLegacyPath(
      source.path,
      caseId: 'c',
      sourceId: 's',
    );
    expect(migrated, startsWith('cases/c/sources/s/'));
    expect(File(storage.resolvePath(migrated)).existsSync(), isTrue);
  });

  test('CCTV/사건 폴더 삭제', () async {
    final source = File('${temp.path}/a.jpg')..writeAsBytesSync([1]);
    await storage.importFile(source.path, caseId: 'c', sourceId: 's1');
    await storage.importFile(source.path, caseId: 'c', sourceId: 's2');
    expect(await storage.totalBytes(), 2);

    await storage.deleteSource('c', 's1');
    expect(Directory('${root.path}/cases/c/sources/s1').existsSync(), isFalse);
    expect(await storage.totalBytes(), 1);

    await storage.deleteCase('c');
    expect(Directory('${root.path}/cases/c').existsSync(), isFalse);
    expect(await storage.totalBytes(), 0);
  });

  test('deleteFile은 없는 파일을 무시', () async {
    await storage.deleteFile('cases/none/none/none.jpg');
    final source = File('${temp.path}/b.jpg')..writeAsBytesSync([1]);
    final relative = await storage.importFile(
      source.path,
      caseId: 'c',
      sourceId: 's',
    );
    await storage.deleteFile(relative);
    expect(File(storage.resolvePath(relative)).existsSync(), isFalse);
  });
}
