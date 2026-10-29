import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/errors/failures.dart';
import '../entities/report_filter.dart';
import '../entities/report_result.dart';

/// عقد مستودع التقارير في طبقة النطاق — قراءة وتجميع فقط.
abstract class ReportsRepository {
  /// توليد التقرير المالي وفق الفلاتر (الحسابات عبر Money).
  Future<Either<Failure, ReportResult>> generateReport(ReportFilter filter);

  /// مراجع المراكز للقائمة المنسدلة في شريط الفلاتر.
  Future<Either<Failure, List<CenterRef>>> getCenterRefs();

  /// الأظرف (نشطة + مؤرشفة) للقائمة المنسدلة في شريط الفلاتر.
  Future<Either<Failure, List<EnvelopeEntity>>> getEnvelopes();
}
