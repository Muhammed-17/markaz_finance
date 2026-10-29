import 'package:go_router/go_router.dart';

import 'presentation/pages/settings_page.dart';

/// مسارات ميزة الإعدادات (داخل الهيكل العام AppShell).
final List<RouteBase> settingsRoutes = <RouteBase>[
  GoRoute(
    path: '/settings',
    name: 'settings',
    builder: (context, state) => const SettingsPage(),
  ),
];
