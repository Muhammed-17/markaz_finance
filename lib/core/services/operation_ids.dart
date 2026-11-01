import '../errors/exceptions.dart';

/// معرّفات المستندات المشتقة من requestId لجعل العمليات المالية idempotent.
///
/// الفكرة: إذا مرّر العميل requestId، تُكتب مستندات العملية بمعرّفات
/// مشتقة منه (لا عشوائية)، فإعادة إرسال العملية نفسها بعد التزام ناجح ضاع
/// ردّه تجد المستند موجودًا وتُعدّ ناجحة دون تنفيذ ثانٍ — فلا يتكرر المبلغ.
/// بدون requestId يبقى السلوك القديم (معرّفات عشوائية).
abstract final class OperationIds {
  static final RegExp _valid = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

  /// هل المعرّف صالح (UUID أو ما يماثله: حروف وأرقام و - و _ بطول 8..64)؟
  static bool isValid(Object? value) => value is String && _valid.hasMatch(value);

  /// requestId الاختياري من بيانات العملية: null إن لم يُرسل،
  /// وخطأ تحقق إن أُرسل بصيغة غير صالحة (لا نخاطر بمعرّف مستند غير آمن).
  static String? optional(Object? raw) {
    if (raw == null) return null;
    if (raw is String && raw.trim().isEmpty) return null;
    if (!isValid(raw)) {
      throw const ValidationException('معرّف الطلب غير صالح');
    }
    return raw as String;
  }

  /// حركة الظرف المقترنة بحركة نقدية أو بصرف سلفة.
  static String envelopeTransaction(String requestId) => '${requestId}_env';

  /// الحركة النقدية المقترنة بصرف سلفة (السلفة نفسها تأخذ requestId).
  static String loanDisbursement(String requestId) => '${requestId}_tx';

  /// معرّف التحويل بين ظرفين؛ تُشتق منه حركتا الخروج والدخول (_out / _in).
  static String transfer(String requestId) => 'tr_$requestId';
}
