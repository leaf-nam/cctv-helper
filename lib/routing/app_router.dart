import 'package:go_router/go_router.dart';

import '../features/cases/presentation/cases_screen.dart';
import '../features/sources/presentation/case_detail_screen.dart';

/// 라우트 등록. 기능 확정 시 docs/architecture/architecture_spec.md와 함께 개정.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CasesScreen(),
    ),
    GoRoute(
      path: '/case/:id',
      builder: (context, state) => CaseDetailScreen(
        caseId: state.pathParameters['id'] ?? '',
      ),
    ),
  ],
);
