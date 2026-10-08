import 'package:go_router/go_router.dart';

import '../features/timeline/presentation/timeline_screen.dart';

/// 라우트 등록 (초안). 기능 확정 시 docs/architecture/architecture_spec.md와 함께 개정.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TimelineScreen(),
    ),
  ],
);
