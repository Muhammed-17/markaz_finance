import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../bloc/auth_bloc.dart';

/// صفحة تسجيل الدخول — نقطة الدخول الوحيدة للنظام.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthBloc>().add(AuthSignInRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ));
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.cardPaddingLarge),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusExtraLarge),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // الشعار والعنوان
                        Container(
                          width: AppDimensions.iconLarge * 2,
                          height: AppDimensions.iconLarge * 2,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusLarge,
                            ),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.textOnPrimary,
                            size: AppDimensions.iconLarge,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing20),
                        Text(
                          AppStrings.appName,
                          style: AppTypography.headlineMedium.copyWith(
                            color: AppColors.primaryDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        const Text(
                          AppStrings.loginSubtitle,
                          style: AppTypography.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.spacing32),

                        AppTextField(
                          label: AppStrings.email,
                          controller: _emailController,
                          hintText: 'example@center.org',
                          prefixIcon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) {
                              return 'البريد الإلكتروني مطلوب';
                            }
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v)) {
                              return 'صيغة البريد الإلكتروني غير صحيحة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacing16),

                        AppTextField(
                          label: AppStrings.password,
                          controller: _passwordController,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: AppDimensions.iconMedium,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          validator: (value) {
                            final v = value ?? '';
                            if (v.isEmpty) return 'كلمة المرور مطلوبة';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacing24),

                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppButton(
                                  label: AppStrings.signIn,
                                  onPressed: isLoading ? null : _submit,
                                  isLoading: isLoading,
                                  icon: Icons.login_rounded,
                                ),
                                const SizedBox(height: AppDimensions.spacing12),
                                OutlinedButton.icon(
                                  onPressed: isLoading
                                      ? null
                                      : () => context.read<AuthBloc>().add(
                                          const AuthGoogleSignInRequested()),
                                  icon:
                                      const Icon(Icons.account_circle_outlined),
                                  label: const Text('تسجيل الدخول عبر Google'),
                                ),
                                const SizedBox(height: AppDimensions.spacing8),
                                const Text(
                                  'الحسابات الجديدة تنتظر موافقة المسؤول قبل دخول النظام',
                                  style: AppTypography.labelSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacing16),

                        const Text(
                          'يتم التحقق من كل العمليات المالية على الخادم قبل تنفيذها '
                          'وفق صلاحيات كل مستخدم',
                          style: AppTypography.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
