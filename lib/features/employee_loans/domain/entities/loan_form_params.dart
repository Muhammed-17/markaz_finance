import 'package:equatable/equatable.dart';

/// معاملات إنشاء سلفة موظف — تُنفذ عبر الدالة السحابية createEmployeeLoan.
///
/// أسماء الحقول مطابقة لعقد الدالة حرفيًا. الظرف المُرسل هو ظرف الصرف
/// (يُخصم منه المبلغ) ولا يُخزن في سجل السلفة حسب التصميم —
/// الربط يتم عبر حركة المصروف المرتبطة.
class CreateLoanParams extends Equatable {
  const CreateLoanParams({
    required this.employeeName,
    this.employeeId,
    required this.totalAmount,
    required this.envelopeId,
    this.notes,
  });

  final String employeeName;

  /// معرّف الموظف (نص اختياري بحسب التصميم).
  final String? employeeId;

  /// إجمالي السلفة بالجنيهات — يتحقق الخادم من كفاية رصيد الظرف
  /// ومن توافق التصنيف (employee_loan) للظرف المخصص نهائيًا.
  final num totalAmount;
  final String envelopeId;
  final String? notes;

  Map<String, dynamic> toCallableData() => {
        'employeeName': employeeName,
        'employeeId': employeeId,
        'totalAmount': totalAmount,
        'envelopeId': envelopeId,
        'notes': notes,
      };

  @override
  List<Object?> get props =>
      [employeeName, employeeId, totalAmount, envelopeId, notes];
}

/// معاملات سداد سلفة — تُنفذ عبر الدالة السحابية repayLoan.
///
/// [requestId] إلزامي وفريد لكل عملية سداد (يولّده العميل عند الإرسال)
/// لمنع تكرار العملية عند انقطاع الشبكة أو إعادة المحاولة —
/// والتحقق النهائي ذري داخل معاملة الخادم.
/// [envelopeId] هو ظرف استلام المبلغ (يزيد رصيده وحساب الخزنة).
class RepayLoanParams extends Equatable {
  const RepayLoanParams({
    required this.loanId,
    required this.amount,
    required this.envelopeId,
    required this.requestId,
    this.notes,
  });

  final String loanId;

  /// مبلغ السداد بالجنيهات — لا يتجاوز المتبقي (يتحقق الخادم ذريًا).
  final num amount;
  final String envelopeId;
  final String requestId;
  final String? notes;

  Map<String, dynamic> toCallableData() => {
        'loanId': loanId,
        'amount': amount,
        'envelopeId': envelopeId,
        'requestId': requestId,
        'notes': notes,
      };

  @override
  List<Object?> get props =>
      [loanId, amount, envelopeId, requestId, notes];
}
