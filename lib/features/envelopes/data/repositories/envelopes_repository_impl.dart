import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/domain/entities/envelope_transaction_entity.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../domain/entities/envelope_form_params.dart';
import '../../domain/entities/envelope_reconciliation_entity.dart';
import '../../domain/repositories/envelopes_repository.dart';
import '../datasources/envelopes_local_data_source.dart';
import '../datasources/envelopes_remote_data_source.dart';

/// تنفيذ عقد مستودع الأظرف المالية.
///
/// - البث المباشر من Firestore مع كتابة عابرة للكاش المحلي (عرض مؤقت).
/// - العمليات المالية تتطلب اتصالًا بالإنترنت وتُنفذ عبر العمليات المالية الذرية.
class EnvelopesRepositoryImpl implements EnvelopesRepository {
  EnvelopesRepositoryImpl({
    required EnvelopesRemoteDataSource remoteDataSource,
    required EnvelopesLocalDataSource localDataSource,
    required ConnectivityService connectivityService,
  })  : _remote = remoteDataSource,
        _local = localDataSource,
        _connectivity = connectivityService;

  final EnvelopesRemoteDataSource _remote;
  final EnvelopesLocalDataSource _local;
  final ConnectivityService _connectivity;

  static const String _offlineFinancialMessage =
      'العمليات المالية تتطلب اتصالًا بالإنترنت';

  @override
  Stream<List<EnvelopeEntity>> watchEnvelopes() {
    return _remote.watchEnvelopes().map((models) {
      // كتابة عابرة للكاش المحلي (للعرض دون اتصال) — لا تعيق البث عند الفشل.
      unawaited(_local.cacheEnvelopes(models));
      return models.map((m) => m.toEntity()).toList();
    });
  }

  @override
  Future<Either<Failure, EnvelopesCacheSnapshot>> getEnvelopesCached() async {
    try {
      final cached = await _local.getCachedEnvelopes();
      return Right(EnvelopesCacheSnapshot(
        envelopes: cached.envelopes.map((m) => m.toEntity()).toList(),
        cachedAt: cached.cachedAt,
        isStale: cached.isStale,
      ));
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<EnvelopeTransactionEntity>>>
      getEnvelopeTransactions(String envelopeId) async {
    try {
      final models = await _remote.fetchEnvelopeTransactions(envelopeId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<CenterRef>>> getCenters() async {
    try {
      return Right(await _remote.fetchCenters());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, String>> createEnvelope(
    EnvelopeFormParams params,
  ) async {
    try {
      if (!await _connectivity.checkNow()) {
        return const Left(NetworkFailure(_offlineFinancialMessage));
      }
      final id = await _remote.createEnvelope(params);
      return Right(id);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateEnvelope(
    UpdateEnvelopeParams params,
  ) async {
    try {
      if (!await _connectivity.checkNow()) {
        return const Left(NetworkFailure(_offlineFinancialMessage));
      }
      await _remote.updateEnvelope(params);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> archiveEnvelope(
    ArchiveEnvelopeParams params,
  ) async {
    try {
      if (!await _connectivity.checkNow()) {
        return const Left(NetworkFailure(_offlineFinancialMessage));
      }
      await _remote.archiveEnvelope(params);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> transferBetweenEnvelopes(
    TransferParams params,
  ) async {
    try {
      if (!await _connectivity.checkNow()) {
        return const Left(NetworkFailure(_offlineFinancialMessage));
      }
      await _remote.transferBetweenEnvelopes(params);
      return const Right(unit);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, EnvelopeReconciliationResult>> reconcileEnvelopes() async {
    try {
      if (!await _connectivity.checkNow()) {
        return const Left(NetworkFailure('التسوية المحاسبية تتطلب اتصالاً بالإنترنت'));
      }
      final result = await _remote.reconcileEnvelopes();
      return Right(result);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
