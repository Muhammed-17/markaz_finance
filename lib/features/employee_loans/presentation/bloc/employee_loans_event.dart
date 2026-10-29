part of 'employee_loans_bloc.dart';

/// أحداث ميزة سلف الموظفين.
sealed class EmployeeLoansEvent extends Equatable {
  const EmployeeLoansEvent();

  @override
  List<Object?> get props => [];
}

/// طلب بدء/تحديث بث السلف بفلتر حالة اختياري:
/// null (الكل) أو 'active' أو 'paid_off'.
final class EmployeeLoansLoadRequested extends EmployeeLoansEvent {
  const EmployeeLoansLoadRequested({this.status});

  final String? status;

  @override
  List<Object?> get props => [status];
}

/// تغيير نص البحث (على اسم الموظف — تصفية محلية).
final class EmployeeLoansSearchQueryChanged extends EmployeeLoansEvent {
  const EmployeeLoansSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// طلب صرف سلفة جديدة.
final class EmployeeLoansCreateRequested extends EmployeeLoansEvent {
  const EmployeeLoansCreateRequested(this.params);

  final CreateLoanParams params;

  @override
  List<Object?> get props => [params];
}

/// طلب تسجيل سداد لسلفة (requestId يولَّد داخل البلوك عند الإرسال).
final class EmployeeLoansRepayRequested extends EmployeeLoansEvent {
  const EmployeeLoansRepayRequested({
    required this.loanId,
    required this.amount,
    required this.envelopeId,
    this.notes,
  });

  final String loanId;
  final num amount;
  final String envelopeId;
  final String? notes;

  @override
  List<Object?> get props => [loanId, amount, envelopeId, notes];
}
