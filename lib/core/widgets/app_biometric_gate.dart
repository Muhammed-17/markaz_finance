import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../constants/app_colors.dart';
import '../services/app_lock_service.dart';
import '../services/biometric_auth_service.dart';

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
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // نافذة البصمة الأصلية تُرسل inactive/resumed. لا تعاملها كخروج
      // من التطبيق وإلا أُعيد القفل فور نجاح التحقق.
      if (!_authenticating && _lockEnabled) _lock();
    } else if (state == AppLifecycleState.resumed && _wasAuthenticated) {
      // لا تعِد قراءة التفضيل هنا: نافذة البصمة نفسها تغيّر دورة حياة التطبيق،
      // وإعادة القراءة كانت تعيد قفل الشاشة فور نجاح التحقق، فتسبب حلقة.
      if (_authenticating) return;
      if (_lockEnabled && _locked) _requestAuthentication();
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
      // لا نعرض قفل البصمة مطلقًا قبل معرفة أن المستخدم فعّله فعليًا.
      _locked = enabled;
    });
    if (enabled) _requestAuthentication();
  }

  Future<void> _requestAuthentication() async {
    if (!_wasAuthenticated || !_lockEnabled || !_locked || _authenticating) {
      return;
    }
    setState(() => _authenticating = true);
    final success = await _biometric.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (success) _locked = false;
    });
  }

  Future<bool> _verifyPasscode(String passcode) async {
    final userId = _userId;
    if (userId == null) return false;
    final success = await _appLock.verifyPasscode(userId, passcode);
    if (success && mounted) setState(() => _locked = false);
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
                  onRetry: _requestAuthentication,
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
                'استخدم البصمة للمتابعة',
                style: TextStyle(color: AppColors.textOnPrimary),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: isAuthenticating ? null : onRetry,
                icon: isAuthenticating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fingerprint_rounded),
                label: Text(
                    isAuthenticating ? 'جارٍ التحقق...' : 'التحقق بالبصمة'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: isAuthenticating
                    ? null
                    : () => _showPasscodeDialog(context),
                child: const Text(
                  'استخدام كلمة مرور التطبيق',
                  style: TextStyle(color: AppColors.textOnPrimary),
                ),
              ),
            ],
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
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('كلمة مرور التطبيق'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'أدخل كلمة المرور',
              errorText: invalid ? 'كلمة المرور غير صحيحة' : null,
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
