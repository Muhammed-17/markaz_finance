import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/audit_log_entities.dart';
import '../../../../core/domain/entities/employee_loan_entity.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../domain/entities/loan_form_params.dart';
import '../../domain/repositories/employee_loans_repository.dart';
import '../datasources/employee_loans_remote_data_source.dart';

/// تنفيذ عقد مستودع سلف الموظفين.
/// العمليات المالية (الصرف والسداد) تتطلب اتصالًا وتُنفذ عبر العمليات المالية الذرية.
class EmployeeLoansRepositoryImpl implements EmployeeLoansRepository {
  EmployeeLoansRepositoryImpl({
    required EmployeeLoansRemoteDataSource remoteDataSource,
    required ConnectivityService connectivityService,
  })  : _remote = remoteDataSource,
        _connectivity = connectivityService;

  final EmployeeLoansRemoteDataSource _remote;
  final ConnectivityService _connectivity;

  static const String _offlineFinancialMessage =
      'العمليات المالية تتطلب اتصالًا بالإنترنت';

  @override
  Stream<List<EmployeeLoanEntity>> watchLoans({String? status}) {
    return _remote
        .watchLoans(status: status)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<Either<Failure, List<LoanPaymentEntity>>> getLoanPayments(
    String loanId,
  ) async {
    try {
      final models = await _remote.fetchLoanPayments(loanId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<LoanLogEntity>>> getLoanLogs(
    String loanId,
  ) async {
    try {
      final models = await _remote.fetchLoanLogs(loanId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<EnvelopeEntity>>> getActiveEnvelopes() async {
    try {
      final models = await _remote.fetchActiveEnvelopesForLoan();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, String>> createLoan(CreateLoanParams params) async {
    try {
      if (!await _connectivity.checkNow()) {
        return const Left(NetworkFailure(_offlineFinancialMessage));
      }
      final loanId = await _remote.createLoan(params);
      return Right(loanId);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> repayLoan(RepayLoanParams params) async {
    try {
      if (!await _connectivity.checkNow()) {
        return const Left(NetworkFailure(_offlineFinancialMessage));
      }
      await _remote.repayLoan(params);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
