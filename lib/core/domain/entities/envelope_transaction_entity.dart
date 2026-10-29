import 'package:equatable/equatable.dart';

/// كيان حركة الظرف — يسجل تغيرات أرصدة الأظرف فقط.
/// لا تُجمع هذه السجلات مع transactions عند حساب إجمالي الإيرادات والمصروفات.
class EnvelopeTransactionEntity extends Equatable {
  const EnvelopeTransactionEntity({
    required this.id,
    required this.envelopeId,
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String envelopeId;

  /// الحركة المالية المرتبطة إن وجدت (تحويلات الأظرف تكون null).
  final String? transactionId;

  /// income / expense / allocation / transfer_in / transfer_out / refund / adjustment.
  final String type;

  /// المبلغ بالجنيه المصري.
  final num amount;
  final String notes;

  /// منفذ العملية (معرّف المستخدم).
  final String createdBy;
  final DateTime createdAt;

  bool get isTransfer => type == 'transfer_in' || type == 'transfer_out';

  @override
  List<Object?> get props =>
      [id, envelopeId, transactionId, type, amount, notes, createdBy, createdAt];
}

