import 'package:get_it/get_it.dart';

import '../../../core/services/financial_operations_service.dart';
import '../../../core/services/firebase_service.dart';
import '../data/datasources/users_remote_data_source.dart';
import '../data/repositories/users_repository_impl.dart';
import '../domain/repositories/users_repository.dart';
import '../domain/usecases/users_usecases.dart';
import '../presentation/bloc/users_bloc.dart';

/// تسجيل اعتماديات ميزة المستخدمين.
///
/// النمط المعتمد لكل الميزات:
/// void registerXxxFeature(GetIt sl) { ... }
void registerUsersFeature(GetIt sl) {
  // DataSource
  sl.registerLazySingleton<UsersRemoteDataSource>(
    () => UsersRemoteDataSource(
      firestore: FirebaseService.firestore,
      operations: sl<FinancialOperationsService>(),
    ),
  );

  // Repository (العقد في domain والتنفيذ في data)
  sl.registerLazySingleton<UsersRepository>(
    () => UsersRepositoryImpl(remoteDataSource: sl<UsersRemoteDataSource>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => WatchUsers(sl<UsersRepository>()));
  sl.registerLazySingleton(() => CreateUser(sl<UsersRepository>()));
  sl.registerLazySingleton(() => UpdateUser(sl<UsersRepository>()));

  // Bloc
  sl.registerFactory<UsersBloc>(
    () => UsersBloc(
      watchUsers: sl<WatchUsers>(),
      createUser: sl<CreateUser>(),
      updateUser: sl<UpdateUser>(),
    ),
  );
}
