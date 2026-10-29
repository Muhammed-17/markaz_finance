import 'package:go_router/go_router.dart';

import 'presentation/pages/users_page.dart';

/// مسارات ميزة المستخدمين (داخل الهيكل العام AppShell).
/// حماية المسار للمديرين فقط موجودة في route_guards.dart.
final List<RouteBase> usersRoutes = <RouteBase>[
  GoRoute(
    path: '/users',
    name: 'users',
    builder: (context, state) => const UsersPage(),
  ),
];
