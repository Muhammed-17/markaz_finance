import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_biometric_gate.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../core/constants/app_strings.dart';
import 'router/app_router.dart';

/// جذر التطبيق: يوفّر AuthBloc على مستوى التطبيق، والثيم العربي RTL،
/// والتنقل عبر GoRouter مع حواجز الحماية.
class QuranFinanceApp extends StatelessWidget {
  const QuranFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => AppRouter.createAuthBloc(),
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // اللغة العربية هي أساس التطبيق مع اتجاه RTL تلقائي.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: AppRouter.router(
        authBloc: context.read<AuthBloc>(),
      ),
      builder: (context, child) {
        // لضمان اتجاه RTL شامل حتى مع التفاف الأنظمة.
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AppBiometricGate(child: child ?? const SizedBox.shrink()),
        );
      },
      color: AppColors.primary,
    );
  }
}
