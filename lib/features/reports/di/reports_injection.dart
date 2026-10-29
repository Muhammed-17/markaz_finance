import 'package:get_it/get_it.dart';

import '../../../core/services/firebase_service.dart';
import '../data/datasources/reports_remote_data_source.dart';
import '../data/repositories/reports_repository_impl.dart';
import '../domain/repositories/reports_repository.dart';
import '../domain/usecases/reports_usecases.dart';
import '../presentation/bloc/reports_bloc.dart';

/// تسجيل اعتماديات ميزة التقارير.
void registerReportsFeature(GetIt sl) {
  // DataSource
  sl.registerLazySingleton<ReportsRemoteDataSource>(
    () => ReportsRemoteDataSource(firestore: FirebaseService.firestore),
  );

  // Repository (العقد في domain والتنفيذ في data)
  sl.registerLazySingleton<ReportsRepository>(
    () => ReportsRepositoryImpl(remoteDataSource: sl<ReportsRemoteDataSource>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => GenerateReport(sl<ReportsRepository>()));
  sl.registerLazySingleton(
      () => LoadReportCenterRefs(sl<ReportsRepository>()));
  sl.registerLazySingleton(() => LoadReportEnvelopes(sl<ReportsRepository>()));

  // Bloc
  sl.registerFactory<ReportsBloc>(
    () => ReportsBloc(generateReport: sl<GenerateReport>()),
  );
}
