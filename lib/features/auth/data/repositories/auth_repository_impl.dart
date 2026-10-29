import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/data/models/user_model.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/hive_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

/// تنفيذ عقد مستودع المصادقة.
///
/// قواعد صارمة:
/// - الدور والصلاحيات تُقرأ من مستند users الموثوق في Firestore فقط،
///   ولا يُثق في أي قيمة مرسلة من العميل.
/// - لا تُخزن أي بيانات اعتماد أو رموز في Hive؛ المخزن المحلي الخاص بالمستخدم
///   يُمسح عند تسجيل الخروج.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required HiveService hiveService,
  })  : _remote = remoteDataSource,
        _hive = hiveService;

  final AuthRemoteDataSource _remote;
  final HiveService _hive;

  String? _cachedUid;

  @override
  Stream<UserProfileEntity?> observeProfile() {
    // نبث المستخدم الموثوق: Auth (من هو؟) × Firestore (دوره وصلاحياته).
    late StreamController<UserProfileEntity?> controller;
    StreamSubscription<UserModel?>? profileSub;

    controller = StreamController<UserProfileEntity?>(
      onCancel: () => profileSub?.cancel(),
    );

    _remote.observeAuthUser().listen((authUser) async {
      profileSub?.cancel();
      if (authUser == null) {
        _cachedUid = null;
        // مسح البيانات الحساسة المرتبطة بالجلسة عند الخروج.
        await _hive.clearUserData();
        controller.add(null);
        return;
      }
      _cachedUid = authUser.uid;
      profileSub = _remote.observeProfile(authUser.uid).listen((profile) {
        if (profile == null || !profile.isActive) {
          // مستند محذوف أو حساب معطل = عدم مصادقة منطقية.
          controller.add(null);
        } else {
          controller.add(profile.toEntity());
        }
      }, onError: (Object e) {
        controller.addError(ErrorHandler.handle(e));
      });
    }, onError: (Object e) {
      controller.addError(ErrorHandler.handle(e));
    });

    return controller.stream;
  }

  @override
  Future<Either<Failure, UserProfileEntity>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final profile = await _remote.signIn(email: email, password: password);
      return Right(profile.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, UserProfileEntity>> signInWithGoogle() async {
    try {
      final profile = await _remote.signInWithGoogle();
      return Right(profile.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _remote.signOut();
      await _hive.clearUserData();
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, UserProfileEntity?>> getCurrentProfile() async {
    try {
      final uid = _cachedUid;
      if (uid == null) return const Right(null);
      final profile = await _remote.fetchProfile(uid);
      if (profile == null || !profile.isActive) return const Right(null);
      return Right(profile.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
