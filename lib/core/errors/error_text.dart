import 'exceptions.dart';
import 'failures.dart';

/// تحويل أي خطأ إلى نص عربي مقروء للمستخدم (بدل toString الخام مثل
/// `AppException(unavailable): ...`).
abstract final class ErrorText {
  static const Set<String> _networkCodes = {
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
  };

  static const String offlineMessage =
      'لا يوجد اتصال بالإنترنت، أعد المحاولة عند عودة الشبكة';

  static String of(
    Object error, {
    String fallback = 'حدث خطأ غير متوقع، حاول مرة أخرى',
  }) {
    if (error is AppException) {
      if (_networkCodes.contains(error.code)) return offlineMessage;
      return error.message;
    }
    if (error is Failure) return error.message;
    return fallback;
  }
}
