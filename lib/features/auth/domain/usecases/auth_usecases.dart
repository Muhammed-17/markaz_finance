import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

/// حالة دخول المستخدم الحالي (يُستخدمها الراوتر والواجهات).
class ObserveAuthProfile {
  const ObserveAuthProfile(this._repository);

  final AuthRepository _repository;

  Stream<UserProfileEntity?> call() => _repository.observeProfile();
}

/// تسجيل الدخول.
class SignInUseCase {
  const SignInUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserProfileEntity>> call({
    required String email,
    required String password,
  }) {
    return _repository.signIn(email: email, password: password);
  }
}

/// تسجيل الخروج.
class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.signOut();
}

/// تسجيل الدخول عبر Google مع انتظار اعتماد المدير للحسابات الجديدة.
class SignInWithGoogleUseCase {
  const SignInWithGoogleUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, UserProfileEntity>> call() =>
      _repository.signInWithGoogle();
}
