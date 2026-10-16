import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 저장소 (SharedPreferences + JSON).
/// 영상 바이너리는 저장하지 않고 메타·오프셋·기록만 저장한다.
class LocalStore {
  final SharedPreferences _prefs;

  LocalStore(this._prefs);

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs);
  }

  /// 키별 문서 목록 저장.
  Future<void> saveAll(String key, List<Map<String, dynamic>> docs) async {
    await _prefs.setString(key, jsonEncode(docs));
  }

  /// 키별 문서 목록 읽기. 없거나 깨졌으면 빈 목록.
  List<Map<String, dynamic>> loadAll(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
