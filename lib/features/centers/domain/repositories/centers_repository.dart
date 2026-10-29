import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/center_entity.dart';

/// عقد مستودع المراكز في طبقة النطاق (Either-based).
abstract class CentersRepository {
  /// بث قائمة المراكز لحظيًا من Firestore (مرتبة بالاسم).
  Stream<Either<Failure, List<CenterEntity>>> watchCenters();

  /// جلب قائمة المراكز: من الشبكة أولًا، وعند تعذر الاتصال يعود
  /// بالقائمة المخزنة محليًا مع isStale = true وطابع زمن التخزين.
  Future<Either<Failure, CentersResult>> getCentersCached();

  /// إضافة مركز جديد.
  Future<Either<Failure, Unit>> addCenter({
    required String name,
    String? description,
  });

  /// تعديل مركز موجود.
  Future<Either<Failure, Unit>> updateCenter({
    required String id,
    required String name,
    String? description,
  });
}
