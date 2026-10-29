import 'package:get_it/get_it.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/services/financial_operations_service.dart';
import '../../../core/services/firebase_service.dart';
import '../data/datasources/employee_loans_remote_data_source.dart';
import '../data/repositories/employee_loans_repository_impl.dart';
import '../domain/repositories/employee_loans_repository.dart';
import '../domain/usecases/employee_loans_usecases.dart';
import '../presentation/bloc/employee_loans_bloc.dart';

/// تسجيل اعتماديات ميزة سلف الموظفين.
/// النمط المعتمد لكل الميزات: void registerXxxFeature(GetIt sl) { ... }
void registerEmployeeLoansFeature(GetIt sl) {
  // DataSource
  sl.registerLazySingleton<EmployeeLoansRemoteDataSource>(
    () => EmployeeLoansRemoteDataSource(
      firestore: FirebaseService.firestore,
      operations: sl<FinancialOperationsService>(),
    ),
  );

  // Repository
  sl.registerLazySingleton<EmployeeLoansRepository>(
    () => EmployeeLoansRepositoryImpl(
      remoteDataSource: sl<EmployeeLoansRemoteDataSource>(),
      connectivityService: sl<ConnectivityService>(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => WatchLoans(sl<EmployeeLoansRepository>()));
  sl.registerLazySingleton(() => GetLoanPayments(sl<EmployeeLoansRepository>()));
  sl.registerLazySingleton(() => GetLoanLogs(sl<EmployeeLoansRepository>()));
  sl.registerLazySingleton(
      () => CreateEmployeeLoan(sl<EmployeeLoansRepository>()));
  sl.registerLazySingleton(() => RepayLoan(sl<EmployeeLoansRepository>()));

  // Blocs
  sl.registerFactory<EmployeeLoansBloc>(
    () => EmployeeLoansBloc(
      watchLoans: sl<WatchLoans>(),
      createEmployeeLoan: sl<CreateEmployeeLoan>(),
      repayLoan: sl<RepayLoan>(),
    ),
  );
}
