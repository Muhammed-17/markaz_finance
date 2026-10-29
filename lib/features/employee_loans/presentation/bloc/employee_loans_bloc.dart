import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/domain/entities/employee_loan_entity.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/loan_form_params.dart';
import '../../domain/usecases/employee_loans_usecases.dart';

part 'employee_loans_event.dart';
part 'employee_loans_state.dart';

/// نوع آخر عملية على السلف (لتمييز رسائل النجاح في الواجهة).
enum EmployeeLoansOperation { none, create, repay }

/// Bloc قائمة سلف الموظفين.
///
/// القائمة من بث Firestore المباشر (فلتر حالة واحد)، وكل العمليات
/// المالية عبر العمليات المالية الذرية — لا نجاح يُعرض إلا بعد تأكيد الخادم.
class EmployeeLoansBloc extends Bloc<EmployeeLoansEvent, EmployeeLoansState> {
  EmployeeLoansBloc({
    required WatchLoans watchLoans,
    required CreateEmployeeLoan createEmployeeLoan,
    required RepayLoan repayLoan,
  })  : _watchLoans = watchLoans,
        _createEmployeeLoan = createEmployeeLoan,
        _repayLoan = repayLoan,
        super(const EmployeeLoansState()) {
    on<EmployeeLoansLoadRequested>(_onLoadRequested, transformer: restartable());
    on<EmployeeLoansSearchQueryChanged>(_onSearchQueryChanged);
    on<EmployeeLoansCreateRequested>(_onCreateRequested);
    on<EmployeeLoansRepayRequested>(_onRepayRequested);
  }

  final WatchLoans _watchLoans;
  final CreateEmployeeLoan _createEmployeeLoan;
  final RepayLoan _repayLoan;

  StreamSubscription<List<EmployeeLoanEntity>>? _loansSubscription;

  Future<void> _onLoadRequested(
    EmployeeLoansLoadRequested event,
    Emitter<EmployeeLoansState> emit,
  ) async {
    await _loansSubscription?.cancel();
    emit(state.copyWith(
      status: state.loans.isEmpty
          ? EmployeeLoansStatus.loading
          : EmployeeLoansStatus.refreshing,
      filterStatus: event.status,
      // عند العودة إلى "الكل" يجب تصفير الفلتر (null لا يُطبق عبر copyWith).
      clearFilterStatus: event.status == null,
    ));

    _loansSubscription = _watchLoans(status: event.status).listen(
      (loans) => emit(state.copyWith(
        status: EmployeeLoansStatus.success,
        loans: loans,
        clearFailure: true,
      )),
      onError: (Object error) {
        final failure = ErrorHandler.handle(error);
        if (state.loans.isEmpty) {
          emit(state.copyWith(
            status: EmployeeLoansStatus.failure,
            failure: failure,
          ));
        } else {
          emit(state.copyWith(
            status: EmployeeLoansStatus.operationFailure,
            failure: failure,
            message: failure.message,
            messageToken: state.messageToken + 1,
            lastOperation: EmployeeLoansOperation.none,
          ));
        }
      },
    );
  }

  void _onSearchQueryChanged(
    EmployeeLoansSearchQueryChanged event,
    Emitter<EmployeeLoansState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  Future<void> _onCreateRequested(
    EmployeeLoansCreateRequested event,
    Emitter<EmployeeLoansState> emit,
  ) async {
    emit(state.copyWith(
      status: EmployeeLoansStatus.submitting,
      lastOperation: EmployeeLoansOperation.create,
      clearFailure: true,
      clearMessage: true,
    ));
    final result = await _createEmployeeLoan(event.params);
    result.fold(
      (failure) => emit(state.copyWith(
        status: EmployeeLoansStatus.operationFailure,
        failure: failure,
        message: failure.message,
        messageToken: state.messageToken + 1,
      )),
      (_) => emit(state.copyWith(
        status: EmployeeLoansStatus.operationCompleted,
        message: 'تم صرف السلفة بنجاح وخصم المبلغ من رصيد الظرف',
        messageToken: state.messageToken + 1,
      )),
    );
  }

  Future<void> _onRepayRequested(
    EmployeeLoansRepayRequested event,
    Emitter<EmployeeLoansState> emit,
  ) async {
    emit(state.copyWith(
      status: EmployeeLoansStatus.submitting,
      lastOperation: EmployeeLoansOperation.repay,
      clearFailure: true,
      clearMessage: true,
    ));

    // معرّف طلب فريد لكل عملية سداد — منع التكرار يتحقق نهائيًا على الخادم
    // داخل المعاملة الذرية (حماية إضافية من إعادة الإرسال عند انقطاع الشبكة).
    final requestId = const Uuid().v4();

    final result = await _repayLoan(RepayLoanParams(
      loanId: event.loanId,
      amount: event.amount,
      envelopeId: event.envelopeId,
      requestId: requestId,
      notes: event.notes,
    ));
    result.fold(
      (failure) => emit(state.copyWith(
        status: EmployeeLoansStatus.operationFailure,
        failure: failure,
        message: failure.message,
        messageToken: state.messageToken + 1,
      )),
      (_) => emit(state.copyWith(
        status: EmployeeLoansStatus.operationCompleted,
        message: 'تم تسجيل السداد بنجاح وزيادة رصيد ظرف الاستلام',
        messageToken: state.messageToken + 1,
      )),
    );
  }

  @override
  Future<void> close() {
    _loansSubscription?.cancel();
    return super.close();
  }
}
