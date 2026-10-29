import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/audit_log_entities.dart';
import '../../../../core/domain/entities/employee_loan_entity.dart';
import '../../../../core/errors/failures.dart';
import '../entities/loan_form_params.dart';
import '../repositories/employee_loans_repository.dart';

/// حالات استخدام ميزة سلف الموظفين.
/// الصرف والسداد يمران عبر المستودع ثم العمليات المالية الذرية حصرًا.

/// بث مباشر لقائمة السلف مع فلتر حالة اختياري.
class WatchLoans {
  const WatchLoans(this._repository);

  final EmployeeLoansRepository _repository;

  Stream<List<EmployeeLoanEntity>> call({String? status}) =>
      _repository.watchLoans(status: status);
}

/// جلب مدفوعات سلفة معينة.
class GetLoanPayments {
  const GetLoanPayments(this._repository);

  final EmployeeLoansRepository _repository;

  Future<Either<Failure, List<LoanPaymentEntity>>> call(String loanId) =>
      _repository.getLoanPayments(loanId);
}

/// جلب سجل تدقيق سلفة معينة.
class GetLoanLogs {
  const GetLoanLogs(this._repository);

  final EmployeeLoansRepository _repository;

  Future<Either<Failure, List<LoanLogEntity>>> call(String loanId) =>
      _repository.getLoanLogs(loanId);
}

/// صرف سلفة جديدة لموظف.
class CreateEmployeeLoan {
  const CreateEmployeeLoan(this._repository);

  final EmployeeLoansRepository _repository;

  Future<Either<Failure, String>> call(CreateLoanParams params) =>
      _repository.createLoan(params);
}

/// سداد جزء من سلفة موظف (requestId يولَّد عند الإرسال لمنع التكرار).
class RepayLoan {
  const RepayLoan(this._repository);

  final EmployeeLoansRepository _repository;

  Future<Either<Failure, Unit>> call(RepayLoanParams params) =>
      _repository.repayLoan(params);
}
