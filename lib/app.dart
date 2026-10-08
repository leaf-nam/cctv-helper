import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/cases/providers/cases_provider.dart';
import 'features/events/providers/events_provider.dart';
import 'features/sources/providers/sources_provider.dart';
import 'routing/app_router.dart';

/// AppShell — MultiProvider + MaterialApp.router.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CasesProvider()),
        ChangeNotifierProvider(create: (_) => SourcesProvider()),
        ChangeNotifierProvider(create: (_) => EventsProvider()),
      ],
      child: MaterialApp.router(
        title: 'cctv-helper',
        routerConfig: appRouter,
      ),
    );
  }
}
