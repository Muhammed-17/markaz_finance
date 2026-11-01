import '../constants/app_constants.dart';
import '../data/models/pending_operation_model.dart';
import 'financial_operations_service.dart';
import 'operation_ids.dart';

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

bool _nonEmpty(Object? v) => v is String && v.trim().isNotEmpty;
bool _positive(Object? v) => v is num && v > 0;

/// إنشاء حركة مالية (createTransaction).
///
/// سياسة التعارض: الخادم يعيد التحقق من الرصيد والظرف النشط والتصنيف المسموح
/// وقت المزامنة. إن تغيّر شيء منها (ظرف أُرشف، رصيد لم يعد يكفي، تصنيف لم يعد
/// مسموحًا) تُرفض المسودة وتبقى «تعذر الاعتماد» بالسبب ليحذفها المستخدم
/// ويسجّلها من جديد؛ لا يُعدَّل أي مبلغ تلقائيًا.
class CreateTransactionHandler extends PendingOperationHandler {
  const CreateTransactionHandler();

  /// الحقول: envelopeId, type, category, name, amount, paymentMethod,
  /// forMonth, notes, requestId, centerId?, branchId?.
  static const int schemaVersion = 1;

  @override
  String get type => AppFunctions.createTransaction;

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  int get minSupportedSchemaVersion => 1;

  @override
  String? validatePayload(Map<String, dynamic> payload) {
    final name = payload['name'];
    final kind = payload['type'];
    final valid = _nonEmpty(payload['envelopeId']) &&
        (kind == 'income' || kind == 'expense') &&
        _nonEmpty(payload['category']) &&
        name is String &&
        name.trim().length >= 3 &&
        _positive(payload['amount']) &&
        _nonEmpty(payload['paymentMethod']) &&
        OperationIds.isValid(payload['requestId']);
    return valid
        ? null
        : 'بيانات مسودة الحركة غير مكتملة — احذفها وسجّل الحركة من جديد';
  }

  @override
  Future<void> execute(
    FinancialOperationsService operations,
    PendingOperationModel operation,
  ) async {
    await operations.call(type, operation.payload);
  }
}

/// صرف سلفة موظف (createEmployeeLoan).
///
/// سياسة التعارض: الخادم يتحقق من كفاية رصيد الظرف وأن الظرف المخصص يشمل
/// بند «سلف الموظفين». عند الرفض تبقى المسودة بالسبب ولا يُصرف شيء.
class CreateEmployeeLoanHandler extends PendingOperationHandler {
  const CreateEmployeeLoanHandler();

  /// الحقول: employeeName, employeeId?, totalAmount, envelopeId, notes?, requestId.
  static const int schemaVersion = 1;

  @override
  String get type => AppFunctions.createEmployeeLoan;

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  int get minSupportedSchemaVersion => 1;

  @override
  String? validatePayload(Map<String, dynamic> payload) {
    final name = payload['employeeName'];
    final valid = name is String &&
        name.trim().length >= 3 &&
        _positive(payload['totalAmount']) &&
        _nonEmpty(payload['envelopeId']) &&
        OperationIds.isValid(payload['requestId']);
    return valid
        ? null
        : 'بيانات مسودة السلفة غير مكتملة — احذفها وسجّل السلفة من جديد';
  }

  @override
  Future<void> execute(
    FinancialOperationsService operations,
    PendingOperationModel operation,
  ) async {
    await operations.call(type, operation.payload);
  }
}

/// تحويل بين ظرفين (transferBetweenEnvelopes) — الأكثر حالات حافة.
///
/// سياسة التعارض: الخادم يتحقق وقت المزامنة من وجود الظرفين وكفاية رصيد المصدر.
/// أي رفض (ظرف محذوف/أُرشف، رصيد نقص) يترك المسودة «تعذر الاعتماد» بالسبب،
/// ولا يتم تحويل جزئي: العملية ذرية بالكامل أو لا شيء.
class TransferEnvelopesHandler extends PendingOperationHandler {
  const TransferEnvelopesHandler();

  /// الحقول: fromEnvelopeId, toEnvelopeId, amount, notes?, requestId.
  static const int schemaVersion = 1;

  @override
  String get type => AppFunctions.transferBetweenEnvelopes;

  @override
  int get currentSchemaVersion => schemaVersion;

  @override
  int get minSupportedSchemaVersion => 1;

  @override
  String? validatePayload(Map<String, dynamic> payload) {
    final from = payload['fromEnvelopeId'];
    final to = payload['toEnvelopeId'];
    final valid = _nonEmpty(from) &&
        _nonEmpty(to) &&
        from != to &&
        _positive(payload['amount']) &&
        OperationIds.isValid(payload['requestId']);
    return valid
        ? null
        : 'بيانات مسودة التحويل غير مكتملة — احذفها وسجّل التحويل من جديد';
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
      PendingOperationRegistry(const [
        RepayLoanHandler(),
        CreateTransactionHandler(),
        CreateEmployeeLoanHandler(),
        TransferEnvelopesHandler(),
      ]);

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
