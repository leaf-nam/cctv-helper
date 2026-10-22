import 'package:flutter/foundation.dart';

import '../../../core/constants/store_keys.dart';
import '../../../core/services/local_store.dart';

/// 첫 실행 튜토리얼 노출 여부를 관리한다.
///
/// [LocalStore]가 없으면(테스트 등) 이미 본 상태로 시작해 기존 화면 흐름을
/// 방해하지 않는다. 실제 앱에서는 `load()`가 저장값을 읽는다.
class TutorialProvider extends ChangeNotifier {
  final LocalStore? _store;
  bool _seen = true;

  TutorialProvider(this._store);

  bool get seen => _seen;

  void load() {
    final store = _store;
    if (store == null) return;
    _seen = store.getBool(StoreKeys.tutorialSeen);
    notifyListeners();
  }

  Future<void> markSeen() async {
    if (_seen) return;
    _seen = true;
    notifyListeners();
    await _store?.setBool(StoreKeys.tutorialSeen, true);
  }
}
