import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/transaction_entity.dart';

/// نموذج الحركة المالية للتحويل من وإلى Firestore.
/// مطابق لتصميم مجموعة transactions.
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.envelopeId,
    required this.centerId,
    required this.branchId,
    required this.notes,
    required this.status,
    required this.paymentMethod,
    required this.createdBy,
    required this.createdAt,
    this.name,
    this.employeeLoanId,
    this.attachmentPaths = const [],
    this.forMonth,
  });

  final String id;

  /// 'income' أو 'expense'.
  final String type;

  /// تصنيف الحركة (AppIncomeCategories أو AppExpenseCategories).
  final String category;

  final String? name;

  /// المبلغ بالجنيه المصري.
  final num amount;

  /// معرّف الظرف المالي المرتبط.
  final String envelopeId;

  /// معرّف المركز.
  final String centerId;

  /// معرّف الفرع (اختياري).
  final String? branchId;

  final String notes;

  /// 'active' أو 'cancelled'.
  final String status;

  /// طريقة الدفع/التحصيل.
  final String paymentMethod;

  final String createdBy;
  final DateTime createdAt;

  final String? employeeLoanId;
  final List<String> attachmentPaths;

  /// الشهر المالي (yyyy-MM) — مُحسوب أو مُدخل يدويًا.
  final String? forMonth;

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return TransactionModel(
      id: id,
      type: (map['type'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      name: map['name'] as String?,
      amount: (map['amount'] ?? 0) as num,
      envelopeId: (map['envelopeId'] ?? '') as String,
      centerId: (map['centerId'] ?? '') as String,
      branchId: map['branchId'] as String?,
      notes: (map['notes'] ?? '') as String,
      status: (map['status'] ?? '') as String,
      paymentMethod: (map['paymentMethod'] ?? '') as String,
      createdBy: (map['createdBy'] ?? '') as String,
      createdAt: _toDateTime(map['createdAt']),
      employeeLoanId: map['employeeLoanId'] as String?,
      attachmentPaths: (map['attachmentPaths'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      forMonth: map['forMonth'] as String?,
    );
  }

  factory TransactionModel.fromSnapshot(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      TransactionModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  TransactionEntity toEntity() => TransactionEntity(
        id: id,
        centerId: centerId,
        branchId: branchId,
        envelopeId: envelopeId,
        type: type,
        category: category,
        name: name ?? notes,
        amount: amount,
        paymentMethod: paymentMethod,
        forMonth: forMonth,
        status: status,
        employeeLoanId: employeeLoanId,
        attachmentPaths: attachmentPaths,
        notes: notes,
        createdAt: createdAt,
      );

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
