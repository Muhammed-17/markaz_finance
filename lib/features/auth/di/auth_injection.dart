import 'package:get_it/get_it.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/hive_service.dart';
import '../data/datasources/auth_remote_data_source.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/auth_usecases.dart';
import '../presentation/bloc/auth_bloc.dart';

/// تسجيل اعتماديات ميزة المصادقة.
///
/// النمط المعتمد لكل الميزات:
/// void registerXxxFeature(GetIt sl) { ... }
void registerAuthFeature(GetIt sl) {
  // DataSource
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(
      auth: FirebaseService.auth,
      firestore: FirebaseService.firestore,
      connectivityService: sl<ConnectivityService>(),
    ),
  );

  // Repository (العقد في domain والتنفيذ في data)
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSource>(),
      hiveService: sl<HiveService>(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => ObserveAuthProfile(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SignInUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(
      () => SignInWithGoogleUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SignOutUseCase(sl<AuthRepository>()));

  // Bloc
  sl.registerLazySingleton<AuthBloc>(
    () => AuthBloc(
      observeAuthProfile: sl<ObserveAuthProfile>(),
      signIn: sl<SignInUseCase>(),
      signInWithGoogle: sl<SignInWithGoogleUseCase>(),
      signOut: sl<SignOutUseCase>(),
    ),
  );
}
