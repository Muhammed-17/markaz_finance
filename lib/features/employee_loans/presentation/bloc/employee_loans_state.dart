part of 'employee_loans_bloc.dart';

/// حالات شاشة سلف الموظفين.
enum EmployeeLoansStatus {
  initial,
  loading,
  refreshing,
  success,
  failure,
  submitting,
  operationCompleted,
  operationFailure,
}

final class EmployeeLoansState extends Equatable {
  const EmployeeLoansState({
    this.status = EmployeeLoansStatus.initial,
    this.loans = const [],
    this.searchQuery = '',
    this.filterStatus,
    this.failure,
    this.message,
    this.messageToken = 0,
    this.lastOperation = EmployeeLoansOperation.none,
  });

  final EmployeeLoansStatus status;

  /// السلف المحملة من البث (وفق فلتر الحالة الحالي).
  final List<EmployeeLoanEntity> loans;
  final String searchQuery;

  /// فلتر الحالة الحالي: null (الكل) / 'active' / 'paid_off'.
  final String? filterStatus;
  final Failure? failure;

  /// رسالة آخر عملية (نجاح أو فشل) — ترافقها [messageToken]
  /// لضمان إطلاق تنبيه جديد حتى تكررت الرسالة نفسها.
  final String? message;
  final int messageToken;
  final EmployeeLoansOperation lastOperation;

  /// السلف الظاهرة بعد تصفية البحث على اسم الموظف.
  List<EmployeeLoanEntity> get visibleLoans {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return loans;
    return loans
        .where((l) => l.employeeName.toLowerCase().contains(query))
        .toList();
  }

  /// إجمالي السلف القائمة (active) من القائمة المحملة محليًا.
  num get activeTotalAmount {
    var total = 0.0;
    for (final loan in loans) {
      if (loan.isActive) total += loan.totalAmount;
    }
    return total;
  }

  /// إجمالي المتبقي على السلف القائمة من القائمة المحملة محليًا.
  num get activeRemainingAmount {
    var total = 0.0;
    for (final loan in loans) {
      if (loan.isActive) total += loan.remainingBalance;
    }
    return total;
  }

  bool get isSubmitting => status == EmployeeLoansStatus.submitting;

  EmployeeLoansState copyWith({
    EmployeeLoansStatus? status,
    List<EmployeeLoanEntity>? loans,
    String? searchQuery,
    String? filterStatus,
    Failure? failure,
    String? message,
    int? messageToken,
    EmployeeLoansOperation? lastOperation,
    bool clearFailure = false,
    bool clearMessage = false,
    bool clearFilterStatus = false,
  }) {
    return EmployeeLoansState(
      status: status ?? this.status,
      loans: loans ?? this.loans,
      searchQuery: searchQuery ?? this.searchQuery,
      filterStatus:
          clearFilterStatus ? null : (filterStatus ?? this.filterStatus),
      failure: clearFailure ? null : (failure ?? this.failure),
      message: clearMessage ? null : (message ?? this.message),
      messageToken: messageToken ?? this.messageToken,
      lastOperation: lastOperation ?? this.lastOperation,
    );
  }

  @override
  List<Object?> get props => [
        status, loans, searchQuery, filterStatus, failure, message,
        messageToken, lastOperation,
      ];
}
