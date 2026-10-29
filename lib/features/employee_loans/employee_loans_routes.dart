import 'package:go_router/go_router.dart';

import 'presentation/pages/loan_details_page.dart';
import 'presentation/pages/loans_page.dart';

/// مسارات ميزة سلف الموظفين (داخل الهيكل العام AppShell).
final List<RouteBase> employeeLoansRoutes = <RouteBase>[
  GoRoute(
    path: '/loans',
    name: 'loans',
    builder: (context, state) => const LoansPage(),
    routes: [
      GoRoute(
        path: ':loanId',
        name: 'loan-details',
        builder: (context, state) => LoanDetailsPage(
          loanId: state.pathParameters['loanId']!,
        ),
      ),
    ],
  ),
];
