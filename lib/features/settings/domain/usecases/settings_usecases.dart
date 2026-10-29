import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/settings_repository.dart';

/// مسح البيانات المؤقتة المحلية (المسودات وذاكرة التخزين المؤقت).
///
/// ملاحظة: الإعدادات العامة مثل تفضيلات العرض تبقى،
/// والبيانات الحساسة تُمسح تلقائيًا عند تسجيل الخروج أيضًا.
class ClearCacheUseCase {
  const ClearCacheUseCase(this._repository);

  final SettingsRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.clearUserData();
}

/// قراءة تفضيل الوضع الداكن من التخزين المحلي.
///
/// تفضيل عرض فقط — تنفيذ الثيم الداكن الفعلي يأتي في إصدار لاحق.
class GetDarkModePreference {
  const GetDarkModePreference(this._repository);

  final SettingsRepository _repository;

  bool call() => _repository.getDarkModePreference();
}

/// حفظ تفضيل الوضع الداكن في التخزين المحلي.
class SaveDarkModePreference {
  const SaveDarkModePreference(this._repository);

  final SettingsRepository _repository;

  Future<Either<Failure, Unit>> call(bool value) =>
      _repository.saveDarkModePreference(value);
}
