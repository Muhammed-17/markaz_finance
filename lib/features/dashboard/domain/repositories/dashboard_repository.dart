import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/dashboard_summary.dart';

/// عقد مستودع لوحة التحكم في طبقة النطاق — قراءة فقط.
abstract class DashboardRepository {
  /// جلب الملخص المالي الكامل للوحة التحكم لسنة الملخص الشهري المعطاة.
  Future<Either<Failure, DashboardSummary>> getDashboardSummary({
    required int monthlyYear,
  });
}
