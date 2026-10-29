import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';

/// عقد مستودع الإعدادات المحلية في طبقة النطاق.
///
/// غلاف صغير حول HiveService (التخزين المحلي المؤقت فقط —
/// ليس مصدرًا للأرصدة أو الصلاحيات).
abstract class SettingsRepository {
  /// مسح كل البيانات المحلية الحساسة المرتبطة بالجلسة
  /// (المسودات وذاكرة التخزين المؤقت للقوائم).
  Future<Either<Failure, Unit>> clearUserData();

  /// قراءة تفضيل الوضع الداكن (تفضيل عرض فقط — التنفيذ الفعلي لاحقًا).
  bool getDarkModePreference();

  /// حفظ تفضيل الوضع الداكن.
  Future<Either<Failure, Unit>> saveDarkModePreference(bool value);
}
