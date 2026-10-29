import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// إعدادات قفل التطبيق لكل مستخدم. رمز الاسترداد محفوظ في مساحة مشفّرة
/// خاصة بالنظام ولا يرسل إلى Firebase أو Firestore.
class AppLockService {
  AppLockService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _enabledKey(String userId) => 'app_lock_enabled_$userId';
  String _passcodeKey(String userId) => 'app_lock_passcode_$userId';

  Future<bool> isEnabled(String userId) async =>
      await _storage.read(key: _enabledKey(userId)) == 'true';

  Future<void> enable({required String userId, required String passcode}) async {
    await _storage.write(key: _passcodeKey(userId), value: passcode);
    await _storage.write(key: _enabledKey(userId), value: 'true');
  }

  Future<void> disable(String userId) async {
    await _storage.delete(key: _enabledKey(userId));
    await _storage.delete(key: _passcodeKey(userId));
  }

  Future<bool> verifyPasscode(String userId, String passcode) async =>
      await _storage.read(key: _passcodeKey(userId)) == passcode;
}
