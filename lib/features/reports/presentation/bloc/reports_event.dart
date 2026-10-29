part of 'reports_bloc.dart';

/// أحداث التقارير.
sealed class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

/// طلب توليد تقرير بفلاتر محددة.
final class GenerateReportRequested extends ReportsEvent {
  const GenerateReportRequested(this.filter);

  final ReportFilter filter;

  @override
  List<Object?> get props => [filter];
}
