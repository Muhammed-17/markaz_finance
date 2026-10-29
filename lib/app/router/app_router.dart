import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/permission_service.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_shell.dart';
import '../../features/auth/auth_routes.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/branches/branches_routes.dart';
import '../../features/centers/centers_routes.dart';
import '../../features/dashboard/dashboard_routes.dart';
import '../../features/employee_loans/employee_loans_routes.dart';
import '../../features/envelopes/envelopes_routes.dart';
import '../../features/reports/reports_routes.dart';
import '../../features/settings/settings_routes.dart';
import '../../features/transactions/transactions_routes.dart';
import '../../features/users/users_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/connectivity_service.dart';
import '../../app/di/injection.dart';
import 'route_guards.dart';

/// الراوتر المركزي مع حواجز الحماية والهيكل العام الموحد.
abstract final class AppRouter {
  /// إنشاء AuthBloc من حاوية الاعتماديات (يُستدعى من app.dart).
  static AuthBloc createAuthBloc() => sl<AuthBloc>();

  /// بناء GoRouter مع الاستماع لتغيرات حالة المصادقة.
  static GoRouter router({required AuthBloc authBloc}) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: RoutePaths.splash,
      debugLogDiagnostics: false,
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) => RouteGuards.redirect(state, authBloc.state),
      routes: [
        ...authRoutes,

        // مسار انتظار مؤقت حتى تتضح حالة المصادقة.
        GoRoute(
          path: RoutePaths.splash,
          builder: (context, state) => const _SplashPage(),
        ),

        // الهيكل العام: كل ميزات النظام الداخلية.
        ShellRoute(
          builder: (context, state, child) => _ShellPage(
            location: state.uri.path,
            child: child,
          ),
          routes: [
            ...dashboardRoutes,
            ...transactionsRoutes,
            ...employeeLoansRoutes,
            ...envelopesRoutes,
            ...centersRoutes,
            ...branchesRoutes,
            ...usersRoutes,
            ...reportsRoutes,
            ...settingsRoutes,
          ],
        ),
      ],
      errorBuilder: (context, state) => const _NotFoundPage(),
    );
  }

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');
}

/// صفحة الهيكل: تربط حالة المصادقة والاتصال بعناصر التنقل الموحدة.
class _ShellPage extends StatelessWidget {
  const _ShellPage({required this.location, required this.child});

  final String location;
  final Widget child;

  List<AppNavItem> _navItemsFor(bool isAdmin) {
    return [
      const AppNavItem(
        path: RoutePaths.dashboard,
        label: AppStrings.navDashboard,
        icon: Icons.dashboard_rounded,
        selectedIcon: Icons.dashboard_rounded,
      ),
      const AppNavItem(
        path: RoutePaths.transactions,
        label: AppStrings.navTransactions,
        icon: Icons.receipt_long_rounded,
        selectedIcon: Icons.receipt_long_rounded,
      ),
      const AppNavItem(
        path: RoutePaths.loans,
        label: AppStrings.navLoans,
        icon: Icons.payments_rounded,
        selectedIcon: Icons.payments_rounded,
      ),
      const AppNavItem(
        path: RoutePaths.envelopes,
        label: AppStrings.navEnvelopes,
        icon: Icons.account_balance_wallet_rounded,
        selectedIcon: Icons.account_balance_wallet_rounded,
      ),
      if (isAdmin)
        const AppNavItem(
          path: RoutePaths.centers,
          label: AppStrings.navCenters,
          icon: Icons.account_balance_rounded,
          selectedIcon: Icons.account_balance_rounded,
        ),
      if (isAdmin)
        const AppNavItem(
          path: RoutePaths.branches,
          label: AppStrings.navBranches,
          icon: Icons.corporate_fare_rounded,
          selectedIcon: Icons.corporate_fare_rounded,
        ),
      if (isAdmin)
        const AppNavItem(
          path: RoutePaths.users,
          label: AppStrings.navUsers,
          icon: Icons.group_rounded,
          selectedIcon: Icons.group_rounded,
        ),
      const AppNavItem(
        path: RoutePaths.reports,
        label: AppStrings.navReports,
        icon: Icons.insert_chart_outlined_rounded,
        selectedIcon: Icons.insert_chart_outlined_rounded,
      ),
      const AppNavItem(
        path: RoutePaths.settings,
        label: AppStrings.navSettings,
        icon: Icons.settings_rounded,
        selectedIcon: Icons.settings_rounded,
      ),
    ];
  }

  String _titleFor(String path, List<AppNavItem> items) {
    AppNavItem? best;
    var bestLength = -1;
    for (final item in items) {
      if (path == item.path || path.startsWith('${item.path}/')) {
        if (item.path.length > bestLength) {
          best = item;
          bestLength = item.path.length;
        }
      }
    }
    return best?.label ?? AppStrings.appNameShort;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final profile =
            authState is AuthAuthenticated ? authState.profile : null;
        final isAdmin = PermissionService.isAdmin(profile);
        final navItems = _navItemsFor(isAdmin);

        return StreamBuilder<bool>(
          stream: sl<ConnectivityService>().onConnectivityChanged,
          initialData: sl<ConnectivityService>().isOnline,
          builder: (context, snapshot) {
            final isOnline = snapshot.data ?? true;
            return AppShell(
              appBarTitle: _titleFor(location, navItems),
              isOnline: isOnline,
              navItems: navItems,
              currentProfileName: profile?.name,
              currentProfileRole: profile?.role,
              onSignOut: () async {
                final confirmed = await showAppConfirmDialog(
                  context,
                  title: AppStrings.signOut,
                  message: AppStrings.signOutConfirm,
                  isDanger: true,
                  confirmLabel: AppStrings.signOut,
                );
                if (confirmed && context.mounted) {
                  context.read<AuthBloc>().add(const AuthSignOutRequested());
                }
              },
              child: child,
            );
          },
        );
      },
    );
  }
}

/// شاشة انتظار أثناء تحديد حالة المصادقة.
class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface.withAlpha(31),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppColors.textOnPrimary,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              AppStrings.appName,
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: AppColors.textOnPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// صفحة 404 موحدة.
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.explore_off_rounded,
              size: 56,
              color: AppColors.disabled,
            ),
            const SizedBox(height: 16),
            const Text('الصفحة المطلوبة غير موجودة'),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => context.go(RoutePaths.dashboard),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('العودة إلى لوحة التحكم'),
            ),
          ],
        ),
      ),
    );
  }
}
