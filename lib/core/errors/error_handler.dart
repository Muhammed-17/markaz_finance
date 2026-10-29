import 'package:firebase_auth/firebase_auth.dart';

import 'exceptions.dart';
import 'failures.dart';

/// تحويل أي استثناء تقني إلى Failure عربي مفهوم للمستخدم،
/// مع الاحتفاظ بالتفاصيل التقنية داخل Failure للسجلات فقط.
abstract final class ErrorHandler {
  static Failure handle(Object error, {StackTrace? stackTrace}) {
    if (error is Failure) return error;
    if (error is AppException) return _fromAppException(error);

    // أخطاء المصادقة
    if (error is FirebaseAuthException) {
      return _fromAuthException(error);
    }

    // أخطاء Firestore
    if (error is FirebaseException) {
      final isNetwork = error.code == 'unavailable' ||
          error.code == 'network-request-failed' ||
          error.code == 'deadline-exceeded';
      if (isNetwork) return const NetworkFailure();
      if (error.code == 'permission-denied') {
        // رفض من قواعد الأمان — قيود العمليات المالية على الخادم.
        return const PermissionFailure(
          'لا تمتلك الصلاحية لتنفيذ هذه العملية',
        );
      }
      if (error.code == 'not-found') {
        return const OperationRejectedFailure('السجل المطلوب غير موجود');
      }
      if (error.code == 'aborted' || error.code == 'failed-precondition') {
        return const ConflictFailure();
      }
      return ServerFailure(
        'تعذر إتمام العملية، حاول مرة أخرى',
        code: error.code,
        technicalDetails: error.message,
      );
    }

    // أنواع أخرى شائعة
    final description = error.toString();
    if (description.contains('SocketException') ||
        description.contains('Failed host lookup') ||
        description.contains('Network is unreachable')) {
      return const NetworkFailure();
    }
    if (error is FormatException) {
      return const ValidationFailure('البيانات المدخلة غير صالحة');
    }

    return UnexpectedFailure(description);
  }

  /// تحويل Failure إلى استثناء مناسب لإعادة الرمي عند الحاجة.
  static AppException toException(Failure failure) {
    return ServerException(failure.message,
        code: failure.code, technicalDetails: failure.technicalDetails);
  }

  static Failure _fromAppException(AppException e) {
    switch (e.runtimeType) {
      case const (ValidationException):
        return ValidationFailure(e.message, code: e.code);
      case const (UnauthenticatedException):
        return UnauthenticatedFailure(e.message);
      case const (PermissionDeniedException):
        return PermissionFailure(e.message);
      case const (NetworkException):
        return NetworkFailure(e.message);
      case const (CacheException):
        return CacheFailure(e.message, technicalDetails: e.technicalDetails);
      case const (OperationRejectedException):
        return OperationRejectedFailure(e.message, code: e.code);
      case const (ConflictException):
        return ConflictFailure(e.message);
      case const (ServerException):
        return ServerFailure(e.message,
            code: e.code, technicalDetails: e.technicalDetails);
      default:
        return UnexpectedFailure(e.message);
    }
  }

  static Failure _fromAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return const ValidationFailure('صيغة البريد الإلكتروني غير صحيحة');
      case 'user-disabled':
        return const PermissionFailure('تم تعطيل هذا الحساب، تواصل مع الإدارة');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const OperationRejectedFailure(
          'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        );
      case 'email-already-in-use':
        return const OperationRejectedFailure(
          'هذا البريد الإلكتروني مستخدم بالفعل',
        );
      case 'weak-password':
        return const ValidationFailure(
          'كلمة المرور ضعيفة، يجب ألا تقل عن 8 أحرف',
        );
      case 'too-many-requests':
        return const OperationRejectedFailure(
          'محاولات كثيرة جدًا، انتظر قليلًا ثم أعد المحاولة',
        );
      case 'network-request-failed':
        return const NetworkFailure();
      case 'requires-recent-login':
        return const OperationRejectedFailure(
          'يجب تسجيل الدخول مجددًا لإتمام هذه العملية',
        );
      default:
        return ServerFailure(
          'تعذر تسجيل الدخول، حاول مرة أخرى',
          code: e.code,
          technicalDetails: e.message,
        );
    }
  }
}
