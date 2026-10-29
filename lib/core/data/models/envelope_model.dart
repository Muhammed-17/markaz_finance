import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/envelope_entity.dart';

/// نموذج الظرف المالي للتحويل من وإلى Firestore.
/// مطابق لتصميم مجموعة fundEnvelopes (بدون archivedAt أو archivedBy).
class EnvelopeModel {
  const EnvelopeModel({
    required this.id,
    required this.name,
    required this.purpose,
    required this.fundType,
    required this.allowedExpenseCategories,
    required this.currentBalance,
    required this.centerId,
    required this.status,
    required this.createdAt,
    this.lastEnvTxId,
  });

  final String id;
  final String name;
  final String purpose;
  final String fundType;
  final List<String> allowedExpenseCategories;
  final num currentBalance;
  final String? centerId;
  final String status;
  final DateTime createdAt;
  final String? lastEnvTxId;

  factory EnvelopeModel.fromMap(String id, Map<String, dynamic> map) {
    return EnvelopeModel(
      id: id,
      name: (map['name'] ?? '') as String,
      purpose: (map['purpose'] ?? '') as String,
      fundType: (map['fundType'] ?? '') as String,
      allowedExpenseCategories:
          ((map['allowedExpenseCategories'] ?? <String>[]) as List)
              .whereType<String>()
              .toList(),
      currentBalance: (map['currentBalance'] ?? 0) as num,
      centerId: map['centerId'] as String?,
      status: (map['status'] ?? '') as String,
      createdAt: _toDateTime(map['createdAt']),
      lastEnvTxId: map['lastEnvTxId'] as String?,
    );
  }

  factory EnvelopeModel.fromSnapshot(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      EnvelopeModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  factory EnvelopeModel.fromCachedMap(Map<String, dynamic> map) =>
      EnvelopeModel.fromMap((map['id'] ?? '') as String, map);

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, dynamic> toCachedMap() => {
        'id': id,
        'name': name,
        'purpose': purpose,
        'fundType': fundType,
        'allowedExpenseCategories': allowedExpenseCategories,
        'currentBalance': currentBalance,
        'centerId': centerId,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        if (lastEnvTxId != null) 'lastEnvTxId': lastEnvTxId,
      };

  EnvelopeEntity toEntity() => EnvelopeEntity(
        id: id,
        name: name,
        purpose: purpose,
        fundType: fundType,
        allowedExpenseCategories: allowedExpenseCategories,
        currentBalance: currentBalance,
        centerId: centerId,
        status: status,
        createdAt: createdAt,
        lastEnvTxId: lastEnvTxId,
      );
}
