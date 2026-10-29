import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/data/models/user_model.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_operation_params.dart';
import '../../domain/repositories/users_repository.dart';
import '../datasources/users_remote_data_source.dart';

/// تنفيذ عقد مستودع المستخدمين.
///
/// القراءة من Firestore مباشرة (المدير فقط وفق القواعد)،
/// والكتابة عبر العمليات الذرية المعتمدة فقط. عند فشل القراءة يُبث Failure صلاحية
/// عبر مجرى الخطأ ليظهر في الواجهة برسالة عربية.
class UsersRepositoryImpl implements UsersRepository {
  UsersRepositoryImpl({required UsersRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  final UsersRemoteDataSource _remote;

  @override
  Stream<List<UserProfileEntity>> watchUsers() {
    late StreamController<List<UserProfileEntity>> controller;
    StreamSubscription<List<UserModel>>? subscription;

    controller = StreamController<List<UserProfileEntity>>(
      onCancel: () => subscription?.cancel(),
    );

    subscription = _remote.watchUsers().listen(
          (models) =>
              controller.add(models.map((m) => m.toEntity()).toList()),
          onError: (Object e) =>
              controller.addError(ErrorHandler.handle(e)),
        );

    return controller.stream;
  }

  @override
  Future<Either<Failure, String>> createUser(CreateUserParams params) async {
    try {
      final userId = await _remote.createUser(params);
      return Right(userId);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateUser(UpdateUserParams params) async {
    try {
      await _remote.updateUser(params);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
