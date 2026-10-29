import 'package:equatable/equatable.dart';

/// كيان سجل تدقيق الحركات المالية (مجموعة transactionLogs).
/// تُنشأ هذه السجلات من الخادم فقط ولا يمكن للعميل تعديلها أو حذفها.
class TransactionLogEntity extends Equatable {
  const TransactionLogEntity({
    required this.id,
    required this.transactionId,
    required this.centerId,
    required this.actionType,
    required this.modifiedBy,
    required this.modifiedByName,
    required this.oldValues,
    required this.newValues,
    required this.reason,
    required this.timestamp,
  });

  final String id;
  final String transactionId;
  final String centerId;

  /// CREATE أو UPDATE أو CANCEL.
  final String actionType;
  final String modifiedBy;
  final String modifiedByName;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? reason;
  final DateTime timestamp;

  @override
  List<Object?> get props => [
        id, transactionId, centerId, actionType, modifiedBy, modifiedByName,
        oldValues, newValues, reason, timestamp,
      ];
}

/// كيان سجل تدقيق السلف (مجموعة loanLogs).
/// للتدقيق فقط ولا يُستخدم لحساب الأرصدة.
class LoanLogEntity extends Equatable {
  const LoanLogEntity({
    required this.id,
    required this.loanId,
    required this.actionType,
    required this.performedBy,
    required this.performedByName,
    required this.oldValues,
    required this.newValues,
    required this.reason,
    required this.timestamp,
  });

  final String id;
  final String loanId;

  /// CREATE أو UPDATE أو PAYMENT أو PAYOFF.
  final String actionType;
  final String performedBy;
  final String performedByName;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? reason;
  final DateTime timestamp;

  @override
  List<Object?> get props => [
        id, loanId, actionType, performedBy, performedByName,
        oldValues, newValues, reason, timestamp,
      ];
}

