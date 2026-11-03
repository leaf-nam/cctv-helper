import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 사진 파일 로컬 보관 서비스 (#26).
///
/// 앱 문서 디렉터리 아래 `cases/<caseId>/sources/<sourceId>/` 구조에
/// 사진 원본을 복사해 보관하고, 모델에는 **상대 경로**만 저장한다.
/// OS 캐시 정리로 사진이 유실되는 문제를 막는다.
class PhotoStorageService {
  /// 앱 시작 시 생성된 기본 인스턴스. 위젯에서 상대 경로를 절대 경로로
  /// 바꿀 때 [resolve]를 사용한다.
  static PhotoStorageService? instance;

  /// 사진 보관 루트 디렉터리.
  final Directory root;

  PhotoStorageService(this.root);

  /// 앱 문서 디렉터리에 보관 루트를 만들고 인스턴스를 등록한다.
  static Future<PhotoStorageService> create() async {
    final docs = await getApplicationDocumentsDirectory();
    final casesDir = Directory(_join(docs.path, 'cases'));
    if (!casesDir.existsSync()) {
      await casesDir.create(recursive: true);
    }
    final service = PhotoStorageService(docs);
    instance = service;
    return service;
  }

  /// 저장된 경로를 실제 파일 경로로 변환한다.
  ///
  /// 기존 데이터의 절대 경로는 그대로 돌려주고, 새 상대 경로는 루트와 합친다.
  String resolvePath(String path) {
    if (path.isEmpty) return path;
    final file = File(path);
    if (file.isAbsolute) return path;
    return _join(root.path, path);
  }

  /// 저장된 경로의 [File]. 없으면 null.
  File? fileFor(String path) {
    if (path.isEmpty) return null;
    final file = File(resolvePath(path));
    return file.existsSync() ? file : null;
  }

  /// [caseId]/[sourceId] 폴더에 파일을 복사하고 상대 경로를 돌려준다.
  ///
  /// 이미 상대 경로로 보관 중인 파일은 그대로 돌려준다.
  /// 원본이 없으면 빈 문자열.
  Future<String> importFile(
    String sourcePath, {
    required String caseId,
    required String sourceId,
    String prefix = 'photo',
  }) async {
    if (sourcePath.isEmpty) return '';
    final source = File(sourcePath);
    if (!source.isAbsolute) return sourcePath;
    if (!await source.exists()) return '';

    final ext = _extension(sourcePath);
    final fileName =
        '${_safe(prefix)}_${DateTime.now().microsecondsSinceEpoch}$ext';
    final relative = 'cases/$caseId/sources/$sourceId/$fileName';
    final target = File(_join(root.path, relative));
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    return relative;
  }

  /// 바이트 데이터를 보관 폴더에 저장하고 상대 경로를 돌려준다.
  Future<String> saveBytes(
    Uint8List bytes, {
    required String caseId,
    required String sourceId,
    String prefix = 'photo',
    String extension = '.jpg',
  }) async {
    final fileName =
        '${_safe(prefix)}_${DateTime.now().microsecondsSinceEpoch}'
        '${extension.startsWith('.') ? extension : '.$extension'}';
    final relative = 'cases/$caseId/sources/$sourceId/$fileName';
    final target = File(_join(root.path, relative));
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return relative;
  }

  /// 기존 절대 경로를 보관 폴더로 마이그레이션한다.
  ///
  /// - 빈 경로/이미 상대 경로: 그대로 반환
  /// - 파일이 있으면 복사 후 상대 경로 반환
  /// - 파일이 없으면 빈 문자열 (placeholder 처리)
  Future<String> migrateLegacyPath(
    String path, {
    required String caseId,
    required String sourceId,
    String prefix = 'migrated',
  }) async {
    if (path.isEmpty) return '';
    if (!File(path).isAbsolute) return path;
    return importFile(path, caseId: caseId, sourceId: sourceId, prefix: prefix);
  }

  /// 사진 1개를 삭제한다. 없는 파일은 무시한다.
  Future<void> deleteFile(String path) async {
    if (path.isEmpty) return;
    final file = File(resolvePath(path));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// CCTV(원천) 폴더 전체 삭제. 사건/CCTV 삭제 시 고아 파일을 정리한다.
  Future<void> deleteSource(String caseId, String sourceId) async {
    final dir = Directory(_join(root.path, 'cases/$caseId/sources/$sourceId'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 사건 폴더 전체 삭제.
  Future<void> deleteCase(String caseId) async {
    final dir = Directory(_join(root.path, 'cases/$caseId'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// 보관 중인 사진 전체 용량(byte).
  Future<int> totalBytes() async {
    final casesDir = Directory(_join(root.path, 'cases'));
    if (!await casesDir.exists()) return 0;
    var total = 0;
    await for (final entity in casesDir.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  static String _join(String base, String child) {
    if (base.endsWith('/') || base.endsWith(r'\')) return '$base$child';
    return '$base/$child';
  }

  static String _extension(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return '.jpg';
    final ext = name.substring(dot).toLowerCase();
    if (ext.length > 6) return '.jpg';
    return ext;
  }

  static String _safe(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return sanitized.isEmpty ? 'photo' : sanitized;
  }

  /// 모델에 저장된 경로를 화면 표시용 실제 경로로 변환한다.
  static String resolve(String path) {
    if (path.isEmpty) return path;
    return instance?.resolvePath(path) ?? path;
  }
}
