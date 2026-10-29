part of 'reports_bloc.dart';

/// حالات شاشة التقارير.
enum ReportsStatus { idle, generating, success, failure }

final class ReportsState extends Equatable {
  const ReportsState({
    this.status = ReportsStatus.idle,
    this.result,
    this.filter = const ReportFilter(),
    this.failure,
  });

  final ReportsStatus status;

  /// آخر نتيجة تقرير تم توليدها بنجاح.
  final ReportResult? result;

  /// آخر فلتر استُخدم (أو الفلتر الحالي المختار).
  final ReportFilter filter;

  final Failure? failure;

  bool get isGenerating => status == ReportsStatus.generating;

  ReportsState copyWith({
    ReportsStatus? status,
    ReportResult? result,
    ReportFilter? filter,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ReportsState(
      status: status ?? this.status,
      result: result ?? this.result,
      filter: filter ?? this.filter,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, result, filter, failure];
}
