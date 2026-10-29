import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/envelope_transaction_entity.dart';

/// نموذج حركة الظرف المالي للتحويل من وإلى Firestore.
/// مطابق لتصميم مجموعة envelopeTransactions.
class EnvelopeTransactionModel {
  const EnvelopeTransactionModel({
    required this.id,
    required this.envelopeId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    this.relatedTransactionId,
    this.fromEnvelopeId,
    this.toEnvelopeId,
  });

  final String id;

  /// معرّف الظرف المالي المرتبط.
  final String envelopeId;

  /// نوع الحركة (AppEnvelopeTransactionTypes).
  /// income / expense / allocation / transfer_in / transfer_out / refund / adjustment
  final String type;

  final num amount;
  final num balanceBefore;
  final num balanceAfter;
  final String notes;
  final String createdBy;
  final DateTime createdAt;

  /// الحركة المالية الرئيسية المرتبطة (من مجموعة transactions) إن وُجدت.
  final String? relatedTransactionId;

  /// الظرف المصدر في عمليات التحويل.
  final String? fromEnvelopeId;

  /// الظرف الهدف في عمليات التحويل.
  final String? toEnvelopeId;

  factory EnvelopeTransactionModel.fromMap(
      String id, Map<String, dynamic> map) {
    return EnvelopeTransactionModel(
      id: id,
      envelopeId: (map['envelopeId'] ?? '') as String,
      type: (map['type'] ?? '') as String,
      amount: (map['amount'] ?? 0) as num,
      balanceBefore: (map['balanceBefore'] ?? 0) as num,
      balanceAfter: (map['balanceAfter'] ?? 0) as num,
      notes: (map['notes'] ?? '') as String,
      createdBy: (map['createdBy'] ?? '') as String,
      createdAt: _toDateTime(map['createdAt']),
      relatedTransactionId: (map['relatedTransactionId'] ?? map['transactionId']) as String?,
      fromEnvelopeId: map['fromEnvelopeId'] as String?,
      toEnvelopeId: map['toEnvelopeId'] as String?,
    );
  }

  factory EnvelopeTransactionModel.fromSnapshot(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      EnvelopeTransactionModel.fromMap(
          doc.id, doc.data() ?? <String, dynamic>{});

  EnvelopeTransactionEntity toEntity() => EnvelopeTransactionEntity(
        id: id,
        envelopeId: envelopeId,
        transactionId: relatedTransactionId,
        type: type,
        amount: amount,
        notes: notes,
        createdBy: createdBy,
        createdAt: createdAt,
      );

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
