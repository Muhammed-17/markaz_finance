import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/audit_log_entities.dart';
import '../../../../core/domain/entities/employee_loan_entity.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/errors/failures.dart';
import '../entities/loan_form_params.dart';

/// عقد مستودع سلف الموظفين في طبقة النطاق.
///
/// قواعد صارمة:
/// - القراءة من Firestore مباشرة (استعلام مقروء متوافق مع الفهارس).
/// - الصرف والسداد عبر معاملة Firestore ذريةs حصرًا — لا كتابة من العميل.
/// - remainingBalance يحدّثه الخادم وحده ولا يلمسه العميل بالكتابة.
abstract class EmployeeLoansRepository {
  /// بث مباشر للسلف — فلتر حالة واحد فقط (مساواة) عند تمرير [status]:
  /// 'active' أو 'paid_off' أو null للكل.
  Stream<List<EmployeeLoanEntity>> watchLoans({String? status});

  /// مدفوعات سلفة معينة (تنازليًا بتاريخ السداد).
  Future<Either<Failure, List<LoanPaymentEntity>>> getLoanPayments(
    String loanId,
  );

  /// سجل تدقيق سلفة معينة (آخر 100 سجل تنازليًا).
  Future<Either<Failure, List<LoanLogEntity>>> getLoanLogs(String loanId);

  /// الأظرف النشطة لاختيار ظرف الصرف/الاستلام في النماذج (قراءة مباشرة).
  Future<Either<Failure, List<EnvelopeEntity>>> getActiveEnvelopes();

  /// صرف سلفة جديدة — عبر دالة createEmployeeLoan. يرجع معرف السلفة.
  Future<Either<Failure, String>> createLoan(CreateLoanParams params);

  /// سداد جزء من سلفة — عبر دالة repayLoan (requestId إلزامي لمنع التكرار).
  Future<Either<Failure, Unit>> repayLoan(RepayLoanParams params);
}
