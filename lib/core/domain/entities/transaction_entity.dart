import 'package:equatable/equatable.dart';

/// كيان الحركة المالية — السجل الأساسي للإيرادات والمصروفات الفعلية.
/// الحقول مطابقة تمامًا لتصميم مجموعة transactions (بدون حقول إضافية).
class TransactionEntity extends Equatable {
  const TransactionEntity({
    required this.id,
    required this.centerId,
    required this.branchId,
    required this.envelopeId,
    required this.type,
    required this.category,
    required this.name,
    required this.amount,
    required this.paymentMethod,
    required this.forMonth,
    required this.status,
    required this.employeeLoanId,
    required this.attachmentPaths,
    required this.notes,
    required this.createdAt,
  });

  final String id;

  /// المركز المرتبط بالحركة.
  final String centerId;

  /// الفرع المرتبط بالحركة أو null.
  final String? branchId;

  /// الظرف المرتبط بالحركة.
  final String envelopeId;

  /// 'income' أو 'expense'.
  final String type;

  /// تصنيف الحركة (نص من القوائم المعتمدة).
  final String category;

  /// اسم الحركة أو وصفها المختصر.
  final String name;

  /// المبلغ بالجنيه المصري.
  final num amount;

  /// طريقة الدفع أو التحصيل.
  final String paymentMethod;

  /// الشهر المالي بصيغة YYYY-MM أو null.
  final String? forMonth;

  /// 'active' أو 'cancelled'.
  final String status;

  /// معرّف السلفة المرتبطة أو null.
  final String? employeeLoanId;

  /// مسارات المرفقات في التخزين.
  final List<String> attachmentPaths;

  /// ملاحظات إضافية.
  final String notes;

  /// تاريخ تسجيل الحركة.
  final DateTime createdAt;

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled';
  bool get hasAttachments => attachmentPaths.isNotEmpty;
  bool get isLinkedToLoan => employeeLoanId != null;

  /// أثر الحركة على الرصيد النقدي: موجب للإيراد وسالب للمصروف (الحركات النشطة فقط).
  num get cashEffect => isActive ? (isIncome ? amount : -amount) : 0;

  TransactionEntity copyWith({
    String? id,
    String? centerId,
    String? branchId,
    String? envelopeId,
    String? type,
    String? category,
    String? name,
    num? amount,
    String? paymentMethod,
    String? forMonth,
    String? status,
    String? employeeLoanId,
    List<String>? attachmentPaths,
    String? notes,
    DateTime? createdAt,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      centerId: centerId ?? this.centerId,
      branchId: branchId ?? this.branchId,
      envelopeId: envelopeId ?? this.envelopeId,
      type: type ?? this.type,
      category: category ?? this.category,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      forMonth: forMonth ?? this.forMonth,
      status: status ?? this.status,
      employeeLoanId: employeeLoanId ?? this.employeeLoanId,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, centerId, branchId, envelopeId, type, category, name, amount,
        paymentMethod, forMonth, status, employeeLoanId, attachmentPaths,
        notes, createdAt,
      ];
}

