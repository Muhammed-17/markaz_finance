import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/errors/failures.dart';
import '../entities/report_filter.dart';
import '../entities/report_result.dart';
import '../repositories/reports_repository.dart';

/// توليد التقرير المالي وفق الفلاتر.
class GenerateReport {
  const GenerateReport(this._repository);

  final ReportsRepository _repository;

  Future<Either<Failure, ReportResult>> call(ReportFilter filter) =>
      _repository.generateReport(filter);
}

/// جلب مراجع المراكز لشريط الفلاتر.
class LoadReportCenterRefs {
  const LoadReportCenterRefs(this._repository);

  final ReportsRepository _repository;

  Future<Either<Failure, List<CenterRef>>> call() =>
      _repository.getCenterRefs();
}

/// جلب الأظرف لشريط الفلاتر.
class LoadReportEnvelopes {
  const LoadReportEnvelopes(this._repository);

  final ReportsRepository _repository;

  Future<Either<Failure, List<EnvelopeEntity>>> call() =>
      _repository.getEnvelopes();
}
