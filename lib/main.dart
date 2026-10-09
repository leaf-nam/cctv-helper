import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.create();
  runApp(AppShell(store: store));
}
