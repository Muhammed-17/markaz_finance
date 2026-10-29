import 'package:go_router/go_router.dart';

import 'presentation/pages/centers_page.dart';

/// مسارات ميزة المراكز.
/// النمط المعتمد: كل ميزة تصدّر قائمة RouteBase تُدمج في app_router.dart.
final List<RouteBase> centersRoutes = <RouteBase>[
  GoRoute(
    path: '/centers',
    name: 'centers',
    builder: (context, state) => const CentersPage(),
  ),
];
