import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../services/app_lock_service.dart';
import '../services/biometric_auth_service.dart';
import '../theme/app_typography.dart';

/// يغطي التطبيق بالكامل عند وجود جلسة مستخدم، بما في ذلك أي مسار يصل من
/// إشعار. ويعاد قفله بمجرد انتقال التطبيق للخلفية.
class AppBiometricGate extends StatefulWidget {
  const AppBiometricGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppBiometricGate> createState() => _AppBiometricGateState();
}

class _AppBiometricGateState extends State<AppBiometricGate>
    with WidgetsBindingObserver {
  final BiometricAuthService _biometric = BiometricAuthService();
  final AppLockService _appLock = AppLockService();
  bool _locked = true;
  bool _authenticating = false;
  bool _wasAuthenticated = false;
  bool _lockEnabled = false;
  bool _loadingPreference = false;
  bool _dismissedBiometric = false;
  bool _wasPaused = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // تم الخروج الفعلي من التطبيق إلى الخلفية.
      if (!_authenticating && _lockEnabled) {
        _wasPaused = true;
        _lock();
      }
    } else if (state == AppLifecycleState.resumed && _wasAuthenticated) {
      // عند العودة من الخلفية: إذا لم يكن المستخدم قد ألغى البصمة يدويًا،
      // ولم تكن المصادقة جارية بالفعل، نطلب التحقق.
      if (_wasPaused && _lockEnabled && _locked && !_authenticating && !_dismissedBiometric) {
        _wasPaused = false;
        _requestAuthentication();
      }
      _wasPaused = false;
    }
  }

  void _lock() {
    if (mounted && !_locked) setState(() => _locked = true);
  }

  void _onAuthState(AuthState state) {
    final authenticated = state is AuthAuthenticated;
    if (!authenticated) {
      _wasAuthenticated = false;
      _userId = null;
      _lockEnabled = false;
      _dismissedBiometric = false;
      if (_locked != false) return;
      setState(() => _locked = false);
      return;
    }

    final userId = state.profile.id;
    if (!_wasAuthenticated || _userId != userId) {
      _wasAuthenticated = true;
      _userId = userId;
      _loadLockPreference(userId);
    }
  }

  Future<void> _loadLockPreference(String userId) async {
    if (!mounted || _loadingPreference) return;
    setState(() => _loadingPreference = true);
    final enabled = await _appLock.isEnabled(userId);
    if (!mounted || _userId != userId) return;
    setState(() {
      _loadingPreference = false;
      _lockEnabled = enabled;
      _locked = enabled;
      _dismissedBiometric = false;
    });
    if (enabled) _requestAuthentication();
  }

  Future<void> _requestAuthentication({bool userTriggered = false}) async {
    if (!_wasAuthenticated || !_lockEnabled || !_locked || _authenticating) {
      return;
    }
    setState(() {
      _authenticating = true;
      if (userTriggered) _dismissedBiometric = false;
    });

    final success = await _biometric.authenticate();
    if (!mounted) return;

    setState(() {
      _authenticating = false;
      if (success) {
        _locked = false;
        _dismissedBiometric = false;
      } else {
        // عند إلغاء المستخدم للنافذة أو فشل البصمة، نثبت حالة الإلغاء
        // حتى لا يعيد النظام فتح نافذة البصمة تلقائيًا في حلقة لا تنتهي.
        _dismissedBiometric = true;
      }
    });
  }

  Future<bool> _verifyPasscode(String passcode) async {
    final userId = _userId;
    if (userId == null) return false;
    final success = await _appLock.verifyPasscode(userId, passcode);
    if (success && mounted) {
      setState(() {
        _locked = false;
        _dismissedBiometric = false;
      });
    }
    return success;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (_, state) => _onAuthState(state),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final authenticated = state is AuthAuthenticated;
          if (authenticated && !_wasAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onAuthState(state);
            });
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (authenticated && _lockEnabled && _locked)
                _LockScreen(
                  isAuthenticating: _authenticating,
                  onRetry: () => _requestAuthentication(userTriggered: true),
                  onVerifyPasscode: _verifyPasscode,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.isAuthenticating,
    required this.onRetry,
    required this.onVerifyPasscode,
  });

  final bool isAuthenticating;
  final VoidCallback onRetry;
  final Future<bool> Function(String passcode) onVerifyPasscode;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pagePaddingMobile,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fingerprint_rounded,
                  color: AppColors.textOnPrimary,
                  size: 72,
                ),
                const SizedBox(height: 20),
                const Text(
                  'التطبيق مقفل',
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'استخدم البصمة أو رمز المرور للمتابعة',
                  style: TextStyle(color: AppColors.textOnPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: isAuthenticating ? null : onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(220, AppDimensions.buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                  ),
                  icon: isAuthenticating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint_rounded),
                  label: Text(
                    isAuthenticating ? 'جارٍ التحقق...' : 'التحقق بالبصمة',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: isAuthenticating
                      ? null
                      : () => _showPasscodeDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textOnPrimary,
                    side: const BorderSide(color: AppColors.textOnPrimary),
                    minimumSize: const Size(220, AppDimensions.buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                  ),
                  icon: const Icon(Icons.pin_rounded),
                  label: const Text('استخدام رمز مرور التطبيق'),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: isAuthenticating
                      ? null
                      : () {
                          context
                              .read<AuthBloc>()
                              .add(const AuthSignOutRequested());
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('تسجيل الخروج والدخول بكلمة المرور'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPasscodeDialog(BuildContext context) async {
    final controller = TextEditingController();
    var invalid = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          ),
          title: const Text('رمز مرور التطبيق', style: AppTypography.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل رمز المرور الذي حددته في الإعدادات:',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'رمز المرور',
                  errorText: invalid ? 'رمز المرور غير صحيح' : null,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                ),
                onSubmitted: (_) async {
                  final valid = await onVerifyPasscode(controller.text);
                  if (valid && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  } else if (dialogContext.mounted) {
                    setDialogState(() => invalid = true);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final valid = await onVerifyPasscode(controller.text);
                if (valid && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                } else if (dialogContext.mounted) {
                  setDialogState(() => invalid = true);
                }
              },
              child: const Text('فتح'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}
