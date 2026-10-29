import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/di/injection.dart';
import 'presentation/bloc/dashboard_bloc.dart';
import 'presentation/pages/dashboard_page.dart';

/// مسارات ميزة لوحة التحكم (داخل الهيكل العام AppShell).
/// يوفّر BlocProvider كتلة لوحة التحكم لكل صفحة لضمان استقلالية الميزة.
final List<RouteBase> dashboardRoutes = <RouteBase>[
  GoRoute(
    path: '/dashboard',
    name: 'dashboard',
    builder: (context, state) => BlocProvider<DashboardBloc>(
      create: (_) => sl<DashboardBloc>(),
      child: const DashboardPage(),
    ),
  ),
];
