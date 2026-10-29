import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/center_entity.dart';
import '../repositories/centers_repository.dart';

/// بث قائمة المراكز لحظيًا (متاح للاستخدام في الشاشات الحية).
class WatchCenters {
  const WatchCenters(this._repository);

  final CentersRepository _repository;

  Stream<Either<Failure, List<CenterEntity>>> call() =>
      _repository.watchCenters();
}

/// جلب قائمة المراكز مع الرجوع للكاش المحلي عند تعذر الشبكة.
class GetCentersCached {
  const GetCentersCached(this._repository);

  final CentersRepository _repository;

  Future<Either<Failure, CentersResult>> call() =>
      _repository.getCentersCached();
}

/// إضافة مركز جديد.
class AddCenter {
  const AddCenter(this._repository);

  final CentersRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String name,
    String? description,
  }) {
    return _repository.addCenter(name: name, description: description);
  }
}

/// تعديل مركز موجود.
class UpdateCenter {
  const UpdateCenter(this._repository);

  final CentersRepository _repository;

  Future<Either<Failure, Unit>> call({
    required String id,
    required String name,
    String? description,
  }) {
    return _repository.updateCenter(id: id, name: name, description: description);
  }
}
