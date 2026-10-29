import 'package:go_router/go_router.dart';

import 'presentation/pages/transactions_page.dart';

/// مسارات ميزة الحركات المالية (داخل الهيكل العام AppShell).
final List<RouteBase> transactionsRoutes = <RouteBase>[
  GoRoute(
    path: '/transactions',
    name: 'transactions',
    builder: (context, state) => const TransactionsPage(),
  ),
];
