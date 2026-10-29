import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_operation_params.dart';

/// عقد مستودع المستخدمين في طبقة النطاق — للمديرين فقط.
abstract class UsersRepository {
  /// بث حي لقائمة المستخدمين من مجموعة users (قراءة مباشرة من Firestore).
  ///
  /// المدير فقط يملك صلاحية القراءة وفق قواعد Firestore؛
  /// عند فشل القراءة (صلاحية/شبكة) يبث الخطأ كـ [Failure] عبر مجرى الخطأ.
  Stream<List<UserProfileEntity>> watchUsers();

  /// إنشاء مستخدم جديد عبر عملية createUser الذرية — يُرجع معرف المستخدم.
  Future<Either<Failure, String>> createUser(CreateUserParams params);

  /// تعديل مستخدم قائم عبر عملية updateUser الذرية.
  Future<Either<Failure, Unit>> updateUser(UpdateUserParams params);
}
