import 'package:get_it/get_it.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/hive_service.dart';
import '../data/datasources/centers_local_data_source.dart';
import '../data/datasources/centers_remote_data_source.dart';
import '../data/repositories/centers_repository_impl.dart';
import '../domain/repositories/centers_repository.dart';
import '../domain/usecases/centers_usecases.dart';
import '../presentation/bloc/centers_bloc.dart';

/// تسجيل اعتماديات ميزة المراكز.
///
/// النمط المعتمد لكل الميزات:
/// void registerXxxFeature(GetIt sl) { ... }
void registerCentersFeature(GetIt sl) {
  // DataSources
  sl.registerLazySingleton<CentersRemoteDataSource>(
    () => CentersRemoteDataSource(firestore: FirebaseService.firestore),
  );

  sl.registerLazySingleton<CentersLocalDataSource>(
    () => CentersLocalDataSource(hiveService: sl<HiveService>()),
  );

  // Repository (العقد في domain والتنفيذ في data)
  sl.registerLazySingleton<CentersRepository>(
    () => CentersRepositoryImpl(
      remoteDataSource: sl<CentersRemoteDataSource>(),
      localDataSource: sl<CentersLocalDataSource>(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => WatchCenters(sl<CentersRepository>()));
  sl.registerLazySingleton(() => GetCentersCached(sl<CentersRepository>()));
  sl.registerLazySingleton(() => AddCenter(sl<CentersRepository>()));
  sl.registerLazySingleton(() => UpdateCenter(sl<CentersRepository>()));

  // Bloc
  sl.registerFactory<CentersBloc>(
    () => CentersBloc(
      getCentersCached: sl<GetCentersCached>(),
      addCenter: sl<AddCenter>(),
      updateCenter: sl<UpdateCenter>(),
    ),
  );
}
