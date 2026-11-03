import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/local_store.dart';
import 'core/services/photo_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.create();
  // 사진 보관은 플랫폼 저장소가 없는 환경(웹 테스트 등)에서도 앱이 뜨도록
  // 실패를 허용한다. 실패 시 사진은 기존 절대 경로로만 동작한다.
  PhotoStorageService? photoStorage;
  try {
    photoStorage = await PhotoStorageService.create();
  } catch (_) {
    photoStorage = null;
  }
  runApp(AppShell(store: store, photoStorage: photoStorage));
}
