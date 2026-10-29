import 'package:go_router/go_router.dart';

import 'presentation/pages/envelope_transactions_page.dart';
import 'presentation/pages/envelopes_page.dart';

/// مسارات ميزة الأظرف المالية (داخل الهيكل العام AppShell).
/// الصفحة الفرعية سجل الحركات داخل نفس GoRoute كنمط ميزة الحركات.
final List<RouteBase> envelopesRoutes = <RouteBase>[
  GoRoute(
    path: '/envelopes',
    name: 'envelopes',
    builder: (context, state) => const EnvelopesPage(),
    routes: [
      GoRoute(
        path: ':envelopeId/transactions',
        name: 'envelope-transactions',
        builder: (context, state) => EnvelopeTransactionsPage(
          envelopeId: state.pathParameters['envelopeId']!,
        ),
      ),
    ],
  ),
];
