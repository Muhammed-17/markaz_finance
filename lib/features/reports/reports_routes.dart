import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/di/injection.dart';
import 'presentation/bloc/reports_bloc.dart';
import 'presentation/pages/reports_page.dart';

/// مسارات ميزة التقارير (داخل الهيكل العام AppShell).
/// يوفّر BlocProvider كتلة التقارير لكل صفحة لضمان استقلالية الميزة.
final List<RouteBase> reportsRoutes = <RouteBase>[
  GoRoute(
    path: '/reports',
    name: 'reports',
    builder: (context, state) => BlocProvider<ReportsBloc>(
      create: (_) => sl<ReportsBloc>(),
      child: const ReportsPage(),
    ),
  ),
];
