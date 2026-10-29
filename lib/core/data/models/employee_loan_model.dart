import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/employee_loan_entity.dart';

/// نموذج سلفة الموظف للتحويل من وإلى Firestore.
/// مطابق لتصميم مجموعة employeeLoans (بدون centerId/branchId/حقول زمنية).
class EmployeeLoanModel {
  const EmployeeLoanModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.totalAmount,
    required this.remainingBalance,
    required this.status,
    required this.notes,
    required this.version,
  });

  final String id;
  final String? employeeId;
  final String employeeName;
  final num totalAmount;
  final num remainingBalance;
  final String status;
  final String notes;
  final int version;

  factory EmployeeLoanModel.fromMap(String id, Map<String, dynamic> map) {
    return EmployeeLoanModel(
      id: id,
      employeeId: map['employeeId'] as String?,
      employeeName: (map['employeeName'] ?? '') as String,
      totalAmount: (map['totalAmount'] ?? 0) as num,
      remainingBalance: (map['remainingBalance'] ?? 0) as num,
      status: (map['status'] ?? '') as String,
      notes: (map['notes'] ?? '') as String,
      version: (map['version'] ?? 1) as int,
    );
  }

  factory EmployeeLoanModel.fromSnapshot(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      EmployeeLoanModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  EmployeeLoanEntity toEntity() => EmployeeLoanEntity(
        id: id,
        employeeId: employeeId,
        employeeName: employeeName,
        totalAmount: totalAmount,
        remainingBalance: remainingBalance,
        status: status,
        notes: notes,
        version: version,
      );
}

/// نموذج عملية سداد سلفة للتحويل من وإلى Firestore.
/// مطابق لتصميم مجموعة loanPayments.
class LoanPaymentModel {
  const LoanPaymentModel({
    required this.id,
    required this.loanId,
    required this.paidAmount,
    required this.paymentDate,
    required this.transactionId,
    required this.requestId,
    required this.notes,
  });

  final String id;
  final String loanId;
  final num paidAmount;
  final DateTime paymentDate;
  final String transactionId;
  final String requestId;
  final String notes;

  factory LoanPaymentModel.fromMap(String id, Map<String, dynamic> map) {
    return LoanPaymentModel(
      id: id,
      loanId: (map['loanId'] ?? '') as String,
      paidAmount: (map['paidAmount'] ?? 0) as num,
      paymentDate: _toDateTime(map['paymentDate']),
      transactionId: (map['transactionId'] ?? '') as String,
      requestId: (map['requestId'] ?? '') as String,
      notes: (map['notes'] ?? '') as String,
    );
  }

  factory LoanPaymentModel.fromSnapshot(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      LoanPaymentModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  LoanPaymentEntity toEntity() => LoanPaymentEntity(
        id: id,
        loanId: loanId,
        paidAmount: paidAmount,
        paymentDate: paymentDate,
        transactionId: transactionId,
        requestId: requestId,
        notes: notes,
      );
}
