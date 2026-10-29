import 'package:get_it/get_it.dart';

import '../../../core/services/firebase_service.dart';
import '../data/datasources/dashboard_remote_data_source.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/usecases/dashboard_usecases.dart';
import '../presentation/bloc/dashboard_bloc.dart';

/// تسجيل اعتماديات ميزة لوحة التحكم.
void registerDashboardFeature(GetIt sl) {
  // DataSource
  sl.registerLazySingleton<DashboardRemoteDataSource>(
    () => DashboardRemoteDataSource(firestore: FirebaseService.firestore),
  );

  // Repository (العقد في domain والتنفيذ في data)
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(remoteDataSource: sl<DashboardRemoteDataSource>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetDashboardSummary(sl<DashboardRepository>()));

  // Bloc
  sl.registerFactory<DashboardBloc>(
    () => DashboardBloc(getDashboardSummary: sl<GetDashboardSummary>()),
  );
}
