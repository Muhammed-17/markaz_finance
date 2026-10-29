import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_operation_params.dart';
import '../repositories/users_repository.dart';

/// بث حي لقائمة المستخدمين من Firestore.
class WatchUsers {
  const WatchUsers(this._repository);

  final UsersRepository _repository;

  Stream<List<UserProfileEntity>> call() => _repository.watchUsers();
}

/// إنشاء مستخدم جديد (للمديرين فقط) عبر الدالة السحابية.
class CreateUser {
  const CreateUser(this._repository);

  final UsersRepository _repository;

  Future<Either<Failure, String>> call(CreateUserParams params) =>
      _repository.createUser(params);
}

/// تعديل مستخدم قائم (للمديرين فقط) عبر الدالة السحابية.
class UpdateUser {
  const UpdateUser(this._repository);

  final UsersRepository _repository;

  Future<Either<Failure, Unit>> call(UpdateUserParams params) =>
      _repository.updateUser(params);
}
