import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/branch_entity.dart';
import '../../domain/repositories/branches_repository.dart';
import '../datasources/branches_local_data_source.dart';
import '../datasources/branches_remote_data_source.dart';
import '../models/branch_model.dart';

/// تنفيذ عقد مستودع الفروع.
///
/// استراتيجية الجلب: الشبكة أولًا، وعند فشل الشبكة يعود بالكاش
/// المحلي (مفلترًا على العميل عند الحاجة) مع isStale = true
/// حتى تعرض الواجهة تنبيه البيانات القديمة.
class BranchesRepositoryImpl implements BranchesRepository {
  BranchesRepositoryImpl({
    required BranchesRemoteDataSource remoteDataSource,
    required BranchesLocalDataSource localDataSource,
  })  : _remote = remoteDataSource,
        _local = localDataSource;

  final BranchesRemoteDataSource _remote;
  final BranchesLocalDataSource _local;

  @override
  Stream<Either<Failure, List<BranchEntity>>> watchBranches({
    String? centerId,
  }) async* {
    try {
      await for (final models in _remote.streamBranches(centerId: centerId)) {
        yield Right(_toEntities(models));
      }
    } catch (e) {
      yield Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, BranchesResult>> getBranchesCached({
    String? centerId,
  }) async {
    try {
      final models = await _remote.fetchBranches(centerId: centerId);
      // يُحدَّث الكاش فقط عند جلب القائمة الكاملة (بلا فلتر مركز)
      // حتى لا تُستبدل القائمة المرجعية المخزنة بقائمة جزئية.
      if (centerId == null) {
        await _local.cacheBranches(models);
      }
      return Right(BranchesResult(items: _toEntities(models)));
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      if (failure is NetworkFailure) {
        final cached = _local.getCachedBranches();
        if (cached != null && cached.items.isNotEmpty) {
          var models = cached.items;
          if (centerId != null) {
            models =
                models.where((model) => model.centerId == centerId).toList();
          }
          if (models.isNotEmpty) {
            return Right(
              BranchesResult(
                items: _toEntities(models),
                isStale: true,
                cachedAt: cached.cachedAt,
              ),
            );
          }
        }
      }
      return Left(failure);
    }
  }

  @override
  Future<Either<Failure, List<CenterRef>>> getCenterOptions() async {
    try {
      return Right(await _remote.fetchCentersForFilter());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> addBranch({
    required String centerId,
    required String name,
    String? location,
  }) async {
    try {
      await _remote.addBranch(
        centerId: centerId,
        name: name,
        location: location,
      );
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateBranch({
    required String id,
    required String centerId,
    required String name,
    String? location,
  }) async {
    try {
      await _remote.updateBranch(
        id: id,
        centerId: centerId,
        name: name,
        location: location,
      );
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  static List<BranchEntity> _toEntities(List<BranchModel> models) =>
      models.map((model) => model.toEntity()).toList();
}
