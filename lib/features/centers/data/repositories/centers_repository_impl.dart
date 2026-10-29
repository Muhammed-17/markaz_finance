import 'package:dartz/dartz.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/center_entity.dart';
import '../../domain/repositories/centers_repository.dart';
import '../datasources/centers_local_data_source.dart';
import '../datasources/centers_remote_data_source.dart';
import '../models/center_model.dart';

/// تنفيذ عقد مستودع المراكز.
///
/// استراتيجية الجلب: الشبكة أولًا، وعند فشل الشبكة يعود بالكاش
/// المحلي مع isStale = true حتى تعرض الواجهة تنبيه البيانات القديمة.
class CentersRepositoryImpl implements CentersRepository {
  CentersRepositoryImpl({
    required CentersRemoteDataSource remoteDataSource,
    required CentersLocalDataSource localDataSource,
  })  : _remote = remoteDataSource,
        _local = localDataSource;

  final CentersRemoteDataSource _remote;
  final CentersLocalDataSource _local;

  @override
  Stream<Either<Failure, List<CenterEntity>>> watchCenters() async* {
    try {
      await for (final models in _remote.streamCenters()) {
        yield Right(models.map((model) => model.toEntity()).toList());
      }
    } catch (e) {
      yield Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, CentersResult>> getCentersCached() async {
    try {
      final models = await _remote.fetchCenters();
      // تحديث القائمة المرجعية المخزنة (قوائم مرجعية بلا أرصدة مالية).
      await _local.cacheCenters(models);
      return Right(
        CentersResult(items: _toEntities(models)),
      );
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      if (failure is NetworkFailure) {
        final cached = _local.getCachedCenters();
        if (cached != null && cached.items.isNotEmpty) {
          return Right(
            CentersResult(
              items: _toEntities(cached.items),
              isStale: true,
              cachedAt: cached.cachedAt,
            ),
          );
        }
      }
      return Left(failure);
    }
  }

  @override
  Future<Either<Failure, Unit>> addCenter({
    required String name,
    String? description,
  }) async {
    try {
      await _remote.addCenter(name: name, description: description);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateCenter({
    required String id,
    required String name,
    String? description,
  }) async {
    try {
      await _remote.updateCenter(id: id, name: name, description: description);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  static List<CenterEntity> _toEntities(List<CenterModel> models) =>
      models.map((model) => model.toEntity()).toList();
}
