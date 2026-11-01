import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

/// معاملات إنشاء ظرف مالي — تُنفذ عبر الدالة السحابية createEnvelope.
///
/// أسماء الحقول مطابقة لعقد الدالة على الخادم حرفيًا.
/// الرصيد الافتتاحي اختياري (جنيهات) — عند وجوده تُنشأ الخادم حركة
/// إيراد بتصنيف opening_balance وحركة تخصيص (allocation) ذريًا.
class EnvelopeFormParams extends Equatable {
  const EnvelopeFormParams({
    required this.name,
    required this.purpose,
    required this.fundType,
    required this.allowedExpenseCategories,
    this.centerId,
    this.initialBalance,
  });

  final String name;
  final String purpose;

  /// 'general' أو 'restricted' — لا يمكن تعديله لاحقًا.
  final String fundType;

  /// إلزامية للظرف المخصص — تصنيفات المصروفات المسموح صرفها منه.
  final List<String> allowedExpenseCategories;
  final String? centerId;

  /// الرصيد الافتتاحي بالجنيهات أو null (لا رصيد افتتاحي).
  final num? initialBalance;

  Map<String, dynamic> toCallableData() => {
        'name': name,
        'purpose': purpose,
        'fundType': fundType,
        'allowedExpenseCategories': allowedExpenseCategories,
        'centerId': centerId,
        'initialBalance': initialBalance,
      };

  @override
  List<Object?> get props => [
        name, purpose, fundType, allowedExpenseCategories,
        centerId, initialBalance,
      ];
}

/// معاملات تعديل بيانات ظرف — عبر الدالة السحابية updateEnvelope.
///
/// الحقول المسموحة فقط: name / purpose / allowedExpenseCategories / centerId.
/// ممنوع إرسال currentBalance أو fundType أو status إطلاقًا
/// (الخادم يرفض أي محاولة لتعديلها صراحةً).
class UpdateEnvelopeParams extends Equatable {
  const UpdateEnvelopeParams({
    required this.envelopeId,
    this.name,
    this.purpose,
    this.allowedExpenseCategories,
    this.centerId,
    this.clearCenterId = false,
  });

  final String envelopeId;

  /// null يعني "بدون تغيير" لهذه الحقول.
  final String? name;
  final String? purpose;
  final List<String>? allowedExpenseCategories;

  /// null مع [clearCenterId] = false تعني "بدون تغيير"،
  /// وتمرير null صراحةً مع [clearCenterId] = true يزيل ارتباط المركز.
  final String? centerId;
  final bool clearCenterId;

  Map<String, dynamic> toCallableData() {
    final data = <String, dynamic>{'envelopeId': envelopeId};
    if (name != null) data['name'] = name;
    if (purpose != null) data['purpose'] = purpose;
    if (allowedExpenseCategories != null) {
      data['allowedExpenseCategories'] = allowedExpenseCategories;
    }
    if (centerId != null || clearCenterId) {
      data['centerId'] = centerId;
    }
    return data;
  }

  @override
  List<Object?> get props => [
        envelopeId, name, purpose, allowedExpenseCategories,
        centerId, clearCenterId,
      ];
}

/// معاملات أرشفة/إعادة تنشيط ظرف — عبر الدالة السحابية archiveEnvelope.
/// لا يمكن أرشفة ظرف به رصيد غير صفري (يتحقق الخادم).
class ArchiveEnvelopeParams extends Equatable {
  const ArchiveEnvelopeParams({
    required this.envelopeId,
    required this.status,
  });

  final String envelopeId;

  /// 'active' أو 'archived' فقط.
  final String status;

  Map<String, dynamic> toCallableData() =>
      {'envelopeId': envelopeId, 'status': status};

  /// هل الطلب أرشفة أم إعادة تنشيط؟
  bool get isArchiving => status == AppStatuses.archived;

  @override
  List<Object?> get props => [envelopeId, status];
}

/// معاملات التحويل بين ظرفين — عبر الدالة السحابية transferBetweenEnvelopes.
/// تحويل داخلي: transfer_out من المصدر وtransfer_in إلى الهدف —
/// لا يُعد إيرادًا أو مصروفًا جديدًا للخزنة ولا يغير إجمالي النقد.
class TransferParams extends Equatable {
  const TransferParams({
    required this.fromEnvelopeId,
    required this.toEnvelopeId,
    required this.amount,
    this.notes,
    this.requestId,
  });

  final String fromEnvelopeId;
  final String toEnvelopeId;

  /// المبلغ بالجنيهات — يتحقق الخادم من كفاية رصيد المصدر نهائيًا.
  final num amount;
  final String? notes;

  /// معرّف طلب فريد يولّده العميل: يجعل التحويل idempotent (إعادة الإرسال
  /// بعد نجاح ضاع ردّه لا تحوّل المبلغ مرتين) ويُستخدم نفسه للمسودة المعلّقة.
  final String? requestId;

  Map<String, dynamic> toCallableData() => {
        'fromEnvelopeId': fromEnvelopeId,
        'toEnvelopeId': toEnvelopeId,
        'amount': amount,
        'notes': notes,
        if (requestId != null) 'requestId': requestId,
      };

  @override
  List<Object?> get props =>
      [fromEnvelopeId, toEnvelopeId, amount, notes, requestId];
}
