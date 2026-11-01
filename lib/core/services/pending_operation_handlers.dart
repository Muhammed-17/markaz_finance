import '../constants/app_constants.dart';
import '../data/models/pending_operation_model.dart';
import 'financial_operations_service.dart';

/// معالج نوع واحد من العمليات المعلقة: يعرف إصدارات بنية بياناته المدعومة،
/// ويتحقق منها، وينفّذها على الخادم.
///
/// لكل نوع جديد (إنشاء مصروف، صرف سلفة، تحويل...) معالج خاص به بدل استدعاء
/// عام بـ type وpayload، فيحمل تحققه وسياسة إصداراته معه.
abstract class PendingOperationHandler {
  const PendingOperationHandler();

  /// اسم العملية (= AppFunctions.*).
  String get type;

  /// إصدار بنية الـ payload الذي تكتبه هذه النسخة من التطبيق.
  int get currentSchemaVersion;

  /// أقدم إصدار بنية ما زال هذا المعالج يستطيع إرساله.
  int get minSupportedSchemaVersion;

  /// null إن كانت البيانات صالحة للإرسال، وإلا سبب مقروء للمستخدم.
  String? validatePayload(Map<String, dynamic> payload);

  Future<void> execute(
    FinancialOperationsService operations,
    PendingOperationModel operation,
  );
}

/// سداد سلفة (repayLoan).
class RepayLoanHandler extends PendingOperationHandler {
  const RepayLoanHandler();

  /// إصدار بنية مسودة السداد: loanId, amount, envelopeId, requestId, notes.
  static const int schemaVersion = 1;

  @override
  String get type => AppFunctions.repayLoan;

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  int get minSupportedSchemaVersion => 1;

  @override
  String? validatePayload(Map<String, dynamic> payload) {
    final loanId = payload['loanId'];
    final envelopeId = payload['envelopeId'];
    final requestId = payload['requestId'];
    final amount = payload['amount'];
    final valid = loanId is String &&
        loanId.isNotEmpty &&
        envelopeId is String &&
        envelopeId.isNotEmpty &&
        requestId is String &&
        requestId.length >= 8 &&
        amount is num &&
        amount > 0;
    return valid ? null : 'بيانات مسودة السداد غير مكتملة — احذفها وسجّل السداد من جديد';
  }

  @override
  Future<void> execute(
    FinancialOperationsService operations,
    PendingOperationModel operation,
  ) async {
    await operations.call(type, operation.payload);
  }
}

/// سجل المعالجات بحسب النوع، ويقرر هل المسودة قابلة للإرسال أصلًا.
class PendingOperationRegistry {
  PendingOperationRegistry(Iterable<PendingOperationHandler> handlers)
      : _byType = {for (final h in handlers) h.type: h};

  /// المعالجات المدعومة في هذه النسخة من التطبيق.
  factory PendingOperationRegistry.standard() =>
      PendingOperationRegistry(const [RepayLoanHandler()]);

  final Map<String, PendingOperationHandler> _byType;

  PendingOperationHandler? handlerFor(String type) => _byType[type];

  /// null إن كانت المسودة قابلة للإرسال، وإلا سبب مقروء يُعرض للمستخدم.
  ///
  /// مسودة من نسخة أحدث أو أقدم من المدعوم، أو من نوع مجهول، لا تُرسل أبدًا
  /// (حتى لا يرفضها الخادم بعد إتلاف معناها)، وتبقى محفوظة ليحذفها المستخدم
  /// أو تُرسل بعد تحديث التطبيق.
  String? unsendableReason(PendingOperationModel operation) {
    final handler = _byType[operation.type];
    if (handler == null) {
      return 'نوع العملية غير مدعوم في هذه النسخة من التطبيق';
    }
    if (operation.schemaVersion > handler.currentSchemaVersion) {
      return 'حُفظت هذه المسودة بنسخة أحدث من التطبيق — حدّث التطبيق ثم أعد المزامنة';
    }
    if (operation.schemaVersion < handler.minSupportedSchemaVersion) {
      return 'حُفظت هذه المسودة بنسخة قديمة لم تعد مدعومة — احذفها وسجّل العملية من جديد';
    }
    return handler.validatePayload(operation.payload);
  }
}
