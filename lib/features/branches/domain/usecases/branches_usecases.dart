import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/errors/failures.dart';
import '../entities/branch_entity.dart';
import '../repositories/branches_repository.dart';

/// بث قائمة الفروع لحظيًا (متاح للاستخدام في الشاشات الحية).
class WatchBranches {
  const WatchBranches(this._repository);

  final BranchesRepository _repository;

  Stream<Either<Failure, List<BranchEntity>>> call({String? centerId}) =>
      _repository.watchBranches(centerId: centerId);
}

/// جلب قائمة الفروع مع الرجوع للكاش المحلي عند تعذر الشبكة.
class GetBranchesCached {
  const GetBranchesCached(this._repository);

  final BranchesRepository _repository;

  Future<Either<Failure, BranchesResult>> call({String? centerId}) =>
      _repository.getBranchesCached(centerId: centerId);
}

/// تحميل قائمة المراكز المرجعية للفلاتر والنماذج.
class LoadCenterOptions {
  const LoadCenterOptions(this._repository);

  final BranchesRepository _repository;

  Future<Either<Failure, List<CenterRef>>> call() =>
      _repository.getCenterOptions();
}

/// إضافة فرع جديد تابع لمركز.
class AddBranch {
  const AddBranch(this._repository);

  final BranchesRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String centerId,
    required String name,
    String? location,
  }) {
    return _repository.addBranch(
      centerId: centerId,
      name: name,
      location: location,
    );
  }
}

/// تعديل فرع موجود.
class UpdateBranch {
  const UpdateBranch(this._repository);

  final BranchesRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String id,
    required String centerId,
    required String name,
    String? location,
  }) {
    return _repository.updateBranch(
      id: id,
      centerId: centerId,
      name: name,
      location: location,
    );
  }
}
