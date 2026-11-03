import 'package:go_router/go_router.dart';

import '../features/cases/presentation/cases_screen.dart';
import '../features/onboarding/presentation/tutorial_screen.dart';
import '../features/photos/presentation/photos_screen.dart';
import '../features/sources/presentation/case_detail_screen.dart';
import '../features/timeline/presentation/case_timeline_screen.dart';

/// 라우트 등록. 기능 확정 시 docs/architecture/architecture_spec.md와 함께 개정.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const CasesScreen()),
    GoRoute(
      path: '/case/:id',
      builder: (context, state) =>
          CaseDetailScreen(caseId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/case/:id/photos',
      builder: (context, state) =>
          PhotosScreen(caseId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/case/:id/timeline',
      builder: (context, state) =>
          CaseTimelineScreen(caseId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) =>
          TutorialScreen(replay: state.uri.queryParameters['replay'] == '1'),
    ),
  ],
);
