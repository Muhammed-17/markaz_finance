import 'package:get_it/get_it.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/hive_service.dart';
import '../data/datasources/branches_local_data_source.dart';
import '../data/datasources/branches_remote_data_source.dart';
import '../data/repositories/branches_repository_impl.dart';
import '../domain/repositories/branches_repository.dart';
import '../domain/usecases/branches_usecases.dart';
import '../presentation/bloc/branches_bloc.dart';

/// تسجيل اعتماديات ميزة الفروع.
///
/// النمط المعتمد لكل الميزات:
/// void registerXxxFeature(GetIt sl) { ... }
void registerBranchesFeature(GetIt sl) {
  // DataSources
  sl.registerLazySingleton<BranchesRemoteDataSource>(
    () => BranchesRemoteDataSource(firestore: FirebaseService.firestore),
  );

  sl.registerLazySingleton<BranchesLocalDataSource>(
    () => BranchesLocalDataSource(hiveService: sl<HiveService>()),
  );

  // Repository (العقد في domain والتنفيذ في data)
  sl.registerLazySingleton<BranchesRepository>(
    () => BranchesRepositoryImpl(
      remoteDataSource: sl<BranchesRemoteDataSource>(),
      localDataSource: sl<BranchesLocalDataSource>(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => WatchBranches(sl<BranchesRepository>()));
  sl.registerLazySingleton(() => GetBranchesCached(sl<BranchesRepository>()));
  sl.registerLazySingleton(() => LoadCenterOptions(sl<BranchesRepository>()));
  sl.registerLazySingleton(() => AddBranch(sl<BranchesRepository>()));
  sl.registerLazySingleton(() => UpdateBranch(sl<BranchesRepository>()));

  // Bloc
  sl.registerFactory<BranchesBloc>(
    () => BranchesBloc(
      getBranchesCached: sl<GetBranchesCached>(),
      addBranch: sl<AddBranch>(),
      updateBranch: sl<UpdateBranch>(),
    ),
  );
}
