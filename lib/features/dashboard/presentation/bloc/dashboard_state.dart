part of 'dashboard_bloc.dart';

/// حالات لوحة التحكم.
enum DashboardStatus { initial, loading, refreshing, success, failure }

final class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.summary,
    this.failure,
    this.monthlyYear,
  });

  final DashboardStatus status;
  final DashboardSummary? summary;
  final Failure? failure;

  /// سنة الملخص الشهري المختارة — null تعني السنة الحالية.
  final int? monthlyYear;

  /// السنة الفعلية للملخص الشهري المعروض.
  int get effectiveMonthlyYear => monthlyYear ?? DateTime.now().year;

  bool get isLoading => status == DashboardStatus.loading;

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSummary? summary,
    Failure? failure,
    int? monthlyYear,
    bool clearFailure = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      failure: clearFailure ? null : (failure ?? this.failure),
      monthlyYear: monthlyYear ?? this.monthlyYear,
    );
  }

  @override
  List<Object?> get props => [status, summary, failure, monthlyYear];
}
