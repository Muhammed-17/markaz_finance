import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/report_result.dart';
import '../../domain/usecases/reports_usecases.dart';

part 'reports_event.dart';
part 'reports_state.dart';

/// Bloc التقارير — توليد التقرير وفق الفلاتر.
class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc({required GenerateReport generateReport})
      : _generateReport = generateReport,
        super(const ReportsState()) {
    on<GenerateReportRequested>(_onGenerateRequested,
        transformer: droppable());
  }

  final GenerateReport _generateReport;

  Future<void> _onGenerateRequested(
    GenerateReportRequested event,
    Emitter<ReportsState> emit,
  ) async {
    emit(state.copyWith(
      status: ReportsStatus.generating,
      filter: event.filter,
    ));

    final result = await _generateReport(event.filter);
    result.fold(
      (failure) => emit(state.copyWith(
        status: ReportsStatus.failure,
        failure: failure,
      )),
      (report) => emit(state.copyWith(
        status: ReportsStatus.success,
        result: report,
        filter: event.filter,
        clearFailure: true,
      )),
    );
  }
}
