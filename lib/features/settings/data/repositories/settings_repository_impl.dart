import 'package:dartz/dartz.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/hive_service.dart';
import '../../domain/repositories/settings_repository.dart';

/// تنفيذ عقد مستودع الإعدادات — يلف HiveService حصريًا.
///
/// قواعد صارمة:
/// - Hive للتخزين المؤقت والتفضيلات فقط وليس مصدرًا للأرصدة أو الصلاحيات.
/// - لا تُخزن كلمات المرور أو الرموز الحساسة هنا إطلاقًا.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({required HiveService hiveService})
      : _hive = hiveService;

  final HiveService _hive;

  /// مفتاح تفضيل الوضع الداكن في صندوق settings.
  static const String _isDarkModeKey = 'isDarkMode';

  @override
  Future<Either<Failure, Unit>> clearUserData() async {
    try {
      await _hive.clearUserData();
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  bool getDarkModePreference() => _hive.getSetting<bool>(_isDarkModeKey) ?? false;

  @override
  Future<Either<Failure, Unit>> saveDarkModePreference(bool value) async {
    try {
      await _hive.saveSetting(_isDarkModeKey, value);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
