import 'package:go_router/go_router.dart';

import 'presentation/pages/login_page.dart';

/// مسارات ميزة المصادقة.
/// النمط المعتمد: كل ميزة تصدّر قائمة RouteBase تُدمج في app_router.dart.
final List<RouteBase> authRoutes = <RouteBase>[
  GoRoute(
    path: '/login',
    name: 'login',
    builder: (context, state) => const LoginPage(),
  ),
];
