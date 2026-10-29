import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/audit_log_entities.dart';

/// نموذج سجل تدقيق الحركات (transactionLogs) — يُقرأ فقط من العميل.
class TransactionLogModel {
  const TransactionLogModel({
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
  final String actionType;
  final String modifiedBy;
  final String modifiedByName;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? reason;
  final DateTime timestamp;

  factory TransactionLogModel.fromMap(String id, Map<String, dynamic> map) {
    return TransactionLogModel(
      id: id,
      transactionId: (map['transactionId'] ?? '') as String,
      centerId: (map['centerId'] ?? '') as String,
      actionType: (map['actionType'] ?? '') as String,
      modifiedBy: (map['modifiedBy'] ?? '') as String,
      modifiedByName: (map['modifiedByName'] ?? '') as String,
      oldValues: _toMapOrNull(map['oldValues']),
      newValues: _toMapOrNull(map['newValues']),
      reason: map['reason'] as String?,
      timestamp: _toDateTime(map['timestamp']),
    );
  }

  factory TransactionLogModel.fromSnapshot(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      TransactionLogModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  TransactionLogEntity toEntity() => TransactionLogEntity(
        id: id,
        transactionId: transactionId,
        centerId: centerId,
        actionType: actionType,
        modifiedBy: modifiedBy,
        modifiedByName: modifiedByName,
        oldValues: oldValues,
        newValues: newValues,
        reason: reason,
        timestamp: timestamp,
      );
}

/// نموذج سجل تدقيق السلف (loanLogs) — يُقرأ فقط من العميل.
class LoanLogModel {
  const LoanLogModel({
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
  final String actionType;
  final String performedBy;
  final String performedByName;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String? reason;
  final DateTime timestamp;

  factory LoanLogModel.fromMap(String id, Map<String, dynamic> map) {
    return LoanLogModel(
      id: id,
      loanId: (map['loanId'] ?? '') as String,
      actionType: (map['actionType'] ?? '') as String,
      performedBy: (map['performedBy'] ?? '') as String,
      performedByName: (map['performedByName'] ?? '') as String,
      oldValues: _toMapOrNull(map['oldValues']),
      newValues: _toMapOrNull(map['newValues']),
      reason: map['reason'] as String?,
      timestamp: _toDateTime(map['timestamp']),
    );
  }

  factory LoanLogModel.fromSnapshot(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      LoanLogModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  LoanLogEntity toEntity() => LoanLogEntity(
        id: id,
        loanId: loanId,
        actionType: actionType,
        performedBy: performedBy,
        performedByName: performedByName,
        oldValues: oldValues,
        newValues: newValues,
        reason: reason,
        timestamp: timestamp,
      );
}

Map<String, dynamic>? _toMapOrNull(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.fromMillisecondsSinceEpoch(0);
}

