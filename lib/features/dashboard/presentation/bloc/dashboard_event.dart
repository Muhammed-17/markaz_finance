part of 'dashboard_bloc.dart';

/// أحداث لوحة التحكم.
sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// طلب تحميل/تحديث ملخص اللوحة (بسنة اختيارية للملخص الشهري).
final class DashboardLoadRequested extends DashboardEvent {
  const DashboardLoadRequested({this.monthlyYear});

  /// سنة الملخص الشهري — null تعني الإبقاء على السنة الحالية.
  final int? monthlyYear;

  @override
  List<Object?> get props => [monthlyYear];
}
