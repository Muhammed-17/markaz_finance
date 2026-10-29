import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';

/// يربط تغيرات حالة المصادقة بتحديث راوتر التطبيق.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
          onError: (Object _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// حواجز حماية المسارات — منع الوصول غير المصرح به.
abstract final class RouteGuards {
  /// منطق إعادة التوجيه المركزي:
  /// - حالة مصادقة غير معروفة: انتظر في مكانك (شاشة انتظار).
  /// - غير مسجل: التوجيه إلى /login.
  /// - مسجل: منع العودة إلى /login والتوجيه إلى لوحة التحكم.
  /// - مسارات /users و/centers و/branches: للمديرين فقط.
  static String? redirect(
    GoRouterState state,
    AuthState authState,
  ) {
    final location = state.uri.path;
    final loggingIn = location == RoutePaths.login;

    return switch (authState) {
      AuthUnknown() => location == RoutePaths.splash ? null : RoutePaths.splash,
      AuthLoading() => null, // انتظر حتى تنتهي عملية تسجيل الدخول.
      AuthUnauthenticated() => loggingIn ? null : RoutePaths.login,
      AuthFailure() => loggingIn ? null : RoutePaths.login,
      AuthAuthenticated(:final profile) => () {
          // بعد استعادة جلسة Firebase يبدأ التطبيق من /splash؛ لا تترك
          // المستخدم عليها بعدما وصلت حالته الموثوقة بنجاح.
          if (loggingIn || location == RoutePaths.splash) {
            return RoutePaths.dashboard;
          }
          // الصفحات الإدارية: للمديرين فقط، حتى عند فتح رابط مباشر.
          if ((location.startsWith(RoutePaths.users) ||
                  location.startsWith(RoutePaths.centers) ||
                  location.startsWith(RoutePaths.branches)) &&
              !profile.isAdmin) {
            return RoutePaths.dashboard;
          }
          return null;
        }(),
    };
  }
}

/// مسارات التطبيق المركزية.
abstract final class RoutePaths {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String transactions = '/transactions';
  static const String transactionNew = '/transactions/new';
  static const String loans = '/loans';
  static const String envelopes = '/envelopes';
  static const String centers = '/centers';
  static const String branches = '/branches';
  static const String users = '/users';
  static const String reports = '/reports';
  static const String settings = '/settings';
}
