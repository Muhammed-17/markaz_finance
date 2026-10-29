import 'package:get_it/get_it.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/services/financial_operations_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/hive_service.dart';
import '../data/datasources/envelopes_local_data_source.dart';
import '../data/datasources/envelopes_remote_data_source.dart';
import '../data/repositories/envelopes_repository_impl.dart';
import '../domain/repositories/envelopes_repository.dart';
import '../domain/usecases/envelopes_usecases.dart';
import '../presentation/bloc/envelopes_bloc.dart';

/// تسجيل اعتماديات ميزة الأظرف المالية.
/// النمط المعتمد لكل الميزات: void registerXxxFeature(GetIt sl) { ... }
void registerEnvelopesFeature(GetIt sl) {
  // DataSources
  sl.registerLazySingleton<EnvelopesRemoteDataSource>(
    () => EnvelopesRemoteDataSource(
      firestore: FirebaseService.firestore,
      operations: sl<FinancialOperationsService>(),
    ),
  );

  sl.registerLazySingleton<EnvelopesLocalDataSource>(
    () => EnvelopesLocalDataSource(hiveService: sl<HiveService>()),
  );

  // Repository
  sl.registerLazySingleton<EnvelopesRepository>(
    () => EnvelopesRepositoryImpl(
      remoteDataSource: sl<EnvelopesRemoteDataSource>(),
      localDataSource: sl<EnvelopesLocalDataSource>(),
      connectivityService: sl<ConnectivityService>(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => WatchEnvelopes(sl<EnvelopesRepository>()));
  sl.registerLazySingleton(
      () => GetEnvelopeTransactions(sl<EnvelopesRepository>()));
  sl.registerLazySingleton(() => CreateEnvelope(sl<EnvelopesRepository>()));
  sl.registerLazySingleton(() => UpdateEnvelope(sl<EnvelopesRepository>()));
  sl.registerLazySingleton(() => ArchiveEnvelope(sl<EnvelopesRepository>()));
  sl.registerLazySingleton(
      () => TransferBetweenEnvelopes(sl<EnvelopesRepository>()));

  // Blocs
  sl.registerFactory<EnvelopesBloc>(
    () => EnvelopesBloc(
      watchEnvelopes: sl<WatchEnvelopes>(),
      createEnvelope: sl<CreateEnvelope>(),
      updateEnvelope: sl<UpdateEnvelope>(),
      archiveEnvelope: sl<ArchiveEnvelope>(),
      transferBetweenEnvelopes: sl<TransferBetweenEnvelopes>(),
      repository: sl<EnvelopesRepository>(),
    ),
  );
}
