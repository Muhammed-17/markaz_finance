import 'package:local_auth/local_auth.dart';

/// بوابة المصادقة المحلية للجهاز. لا تعتمد على حالة Firebase ولا تمنح
/// صلاحيات بحد ذاتها؛ هي قفل إضافي فوق جلسة المستخدم المعتمدة.
class BiometricAuthService {
  BiometricAuthService({LocalAuthentication? authentication})
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  Future<bool> authenticate() async {
    try {
      final supported = await _authentication.isDeviceSupported();
      final enrolled = await _authentication.getAvailableBiometrics();
      if (!supported || enrolled.isEmpty) return false;

      return _authentication.authenticate(
        localizedReason: 'تحقق بالبصمة لفتح التطبيق',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
