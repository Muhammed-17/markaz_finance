import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/usecases/dashboard_usecases.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

/// Bloc لوحة التحكم — تحميل الملخص وإعادة التحديث.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({required GetDashboardSummary getDashboardSummary})
      : _getDashboardSummary = getDashboardSummary,
        super(const DashboardState()) {
    on<DashboardLoadRequested>(_onLoadRequested, transformer: droppable());
  }

  final GetDashboardSummary _getDashboardSummary;

  Future<void> _onLoadRequested(
    DashboardLoadRequested event,
    Emitter<DashboardState> emit,
  ) async {
    // عند وجود ملخص سابق نعرض حالة تحديث هادئ دون تفريغ الشاشة.
    emit(state.copyWith(
      status: state.summary == null
          ? DashboardStatus.loading
          : DashboardStatus.refreshing,
      monthlyYear: event.monthlyYear ?? state.monthlyYear,
    ));

    final result =
        await _getDashboardSummary(monthlyYear: state.effectiveMonthlyYear);
    result.fold(
      (failure) => emit(state.copyWith(
        status: DashboardStatus.failure,
        failure: failure,
      )),
      (summary) => emit(state.copyWith(
        status: DashboardStatus.success,
        summary: summary,
        clearFailure: true,
      )),
    );
  }
}
