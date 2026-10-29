import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

/// جلب ملخص لوحة التحكم (الأرصدة، السلف، الأظرف، آخر الحركات، التوزيع الشهري).
class GetDashboardSummary {
  const GetDashboardSummary(this._repository);

  final DashboardRepository _repository;

  Future<Either<Failure, DashboardSummary>> call({required int monthlyYear}) =>
      _repository.getDashboardSummary(monthlyYear: monthlyYear);
}
