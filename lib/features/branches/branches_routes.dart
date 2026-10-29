import 'package:go_router/go_router.dart';

import 'presentation/pages/branches_page.dart';

/// مسارات ميزة الفروع.
/// النمط المعتمد: كل ميزة تصدّر قائمة RouteBase تُدمج في app_router.dart.
final List<RouteBase> branchesRoutes = <RouteBase>[
  GoRoute(
    path: '/branches',
    name: 'branches',
    builder: (context, state) => const BranchesPage(),
  ),
];
