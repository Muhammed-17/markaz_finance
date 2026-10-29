import 'package:equatable/equatable.dart';

/// كيان سلفة الموظف.
/// لا يحوي centerId أو branchId؛ لأن السلفة قد تُصرف على دفعات ومن أكثر من ظرف.
class EmployeeLoanEntity extends Equatable {
  const EmployeeLoanEntity({
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

  /// معرّف الموظف أو null.
  final String? employeeId;
  final String employeeName;

  /// إجمالي السلفة بالجنيه المصري.
  final num totalAmount;

  /// المبلغ المتبقي (المصدر الموثوق Firestore).
  final num remainingBalance;

  /// 'active' أو 'paid_off'.
  final String status;
  final String notes;

  /// رقم إصدار اختياري لمنع التعارض.
  final int version;

  bool get isActive => status == 'active';
  bool get isPaidOff => status == 'paid_off';
  bool get hasPayments => remainingBalance < totalAmount;
  num get paidAmount => totalAmount - remainingBalance;

  /// نسبة المسدد (0.0 - 1.0).
  double get paidRatio =>
      totalAmount <= 0 ? 0 : (paidAmount / totalAmount).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [
        id, employeeId, employeeName, totalAmount, remainingBalance,
        status, notes, version,
      ];
}

/// كيان عملية سداد سلفة.
class LoanPaymentEntity extends Equatable {
  const LoanPaymentEntity({
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

  /// المبلغ المسدد بالجنيه المصري.
  final num paidAmount;
  final DateTime paymentDate;

  /// معرّف حركة الإيراد المرتبطة.
  final String transactionId;

  /// معرّف فريد لمنع تكرار السداد.
  final String requestId;
  final String notes;

  @override
  List<Object?> get props =>
      [id, loanId, paidAmount, paymentDate, transactionId, requestId, notes];
}
