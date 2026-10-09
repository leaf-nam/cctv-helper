import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/local_store.dart';
import 'features/cases/providers/cases_provider.dart';
import 'features/events/providers/events_provider.dart';
import 'features/sources/providers/sources_provider.dart';
import 'routing/app_router.dart';

/// AppShell — MultiProvider + MaterialApp.router.
/// 시작 시 로컬 저장분을 각 Provider에 복원한다.
class AppShell extends StatelessWidget {
  final LocalStore? store;

  const AppShell({super.key, this.store});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CasesProvider(null, store)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => SourcesProvider(null, store)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => EventsProvider(null, store)..load(),
        ),
      ],
      child: MaterialApp.router(
        title: 'cctv-helper',
        routerConfig: appRouter,
      ),
    );
  }
}
