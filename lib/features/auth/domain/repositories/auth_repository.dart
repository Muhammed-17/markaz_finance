import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/errors/failures.dart';

/// عقد مستودع المصادقة في طبقة النطاق.
abstract class AuthRepository {
  /// بث حالة المصادقة المدمجة: المستخدم الحالي أو null.
  /// يدمج Firebase Auth مع مستند users الموثوق (الدور والصلاحيات والحالة).
  ///
  /// إذا صار المستخدم غير نشط (isActive = false) تُبَث قيمة null
  /// وتُنهى الجلسة منطقيًا.
  Stream<UserProfileEntity?> observeProfile();

  /// تسجيل الدخول.
  Future<Either<Failure, UserProfileEntity>> signIn({
    required String email,
    required String password,
  });

  /// دخول Google. الحساب الجديد يبقى غير مفعّل إلى أن يعتمده المدير.
  Future<Either<Failure, UserProfileEntity>> signInWithGoogle();

  /// تسجيل الخروج.
  Future<Either<Failure, Unit>> signOut();

  /// جلب المستخدم الحالي (إن وُجد).
  Future<Either<Failure, UserProfileEntity?>> getCurrentProfile();
}
