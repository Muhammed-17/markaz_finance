/// الاستثناءات التقنية المنخفضة المستوى — تُرمى من مصادر البيانات
/// وتُحوَّل عبر ErrorHandler إلى Failures للعرض.
abstract class AppException implements Exception {
  const AppException(this.message, {this.code, this.technicalDetails});

  final String message;
  final String? code;
  final String? technicalDetails;

  @override
  String toString() => 'AppException($code): $message';
}

/// خطأ من الخادم أو Firestore أو معاملات Firestore الذرية.
class ServerException extends AppException {
  const ServerException(super.message, {super.code, super.technicalDetails});
}

/// خطأ في مدخلات المستخدم أو بيانات غير صالحة.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

/// لا يوجد مستخدم مسجل الدخول أو الجلسة منتهية.
class UnauthenticatedException extends AppException {
  const UnauthenticatedException([super.message = 'يجب تسجيل الدخول أولًا']);
}

/// العملية مرفوضة لعدم امتلاك الصلاحية اللازمة.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([
    super.message = 'لا تمتلك الصلاحية لتنفيذ هذه العملية',
  ]);
}

/// انقطاع الاتصال بالشبكة.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'تعذر الاتصال بالشبكة، تحقق من اتصالك وحاول مرة أخرى',
  ]);
}

/// خطأ في التخزين المحلي Hive.
class CacheException extends AppException {
  const CacheException(super.message, {super.technicalDetails});
}

/// رفض العملية لسبب منطقي (رصيد غير كافٍ، حالة غير مسموحة...).
class OperationRejectedException extends AppException {
  const OperationRejectedException(super.message, {super.code});
}

/// تعارض في الإصدارات (stale version) أثناء التعديل المتزامن.
class ConflictException extends AppException {
  const ConflictException([
    super.message = 'تم تعديل هذا السجل من مستخدم آخر، حدّث البيانات وأعد المحاولة',
  ]);
}

/// استثناء غير متوقع.
class UnexpectedException extends AppException {
  const UnexpectedException(String technicalDetails)
      : super('حدث خطأ غير متوقع، حاول مرة أخرى لاحقًا',
            technicalDetails: technicalDetails);
}
