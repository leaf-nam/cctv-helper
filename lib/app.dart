import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'routing/app_router.dart';

/// AppShell — MultiProvider + MaterialApp.router (초안).
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: const [],
      child: MaterialApp.router(
        title: 'cctv-helper',
        routerConfig: appRouter,
      ),
    );
  }
}
