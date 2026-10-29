import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/errors/failures.dart';
import '../entities/branch_entity.dart';

/// عقد مستودع الفروع في طبقة النطاق (Either-based).
abstract class BranchesRepository {
  /// بث قائمة الفروع لحظيًا من Firestore (مرتبة بالاسم على العميل).
  Stream<Either<Failure, List<BranchEntity>>> watchBranches({String? centerId});

  /// جلب قائمة الفروع: من الشبكة أولًا، وعند تعذر الاتصال يعود
  /// بالقائمة المخزنة محليًا مع isStale = true وطابع زمن التخزين.
  ///
  /// ملاحظة التخزين: الكاش يُحدَّث فقط عند الجلب بلا فلتر مركز (الكل)،
  /// وعند الفشل يُفلتر الكاش المخزن على العميل حسب [centerId].
  Future<Either<Failure, BranchesResult>> getBranchesCached({String? centerId});

  /// قائمة مرجعية مبسطة للمراكز لعرضها في الفلاتر والنماذج (قراءة فقط).
  Future<Either<Failure, List<CenterRef>>> getCenterOptions();

  /// إضافة فرع جديد تابع لمركز.
  Future<Either<Failure, Unit>> addBranch({
    required String centerId,
    required String name,
    String? location,
  });

  /// تعديل فرع موجود.
  Future<Either<Failure, Unit>> updateBranch({
    required String id,
    required String centerId,
    required String name,
    String? location,
  });
}
