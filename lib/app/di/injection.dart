import 'package:get_it/get_it.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/services/financial_operations_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/pending_operations_service.dart';
import '../../features/auth/di/auth_injection.dart';
import '../../features/branches/di/branches_injection.dart';
import '../../features/centers/di/centers_injection.dart';
import '../../features/dashboard/di/dashboard_injection.dart';
import '../../features/employee_loans/di/employee_loans_injection.dart';
import '../../features/envelopes/di/envelopes_injection.dart';
import '../../features/reports/di/reports_injection.dart';
import '../../features/settings/di/settings_injection.dart';
import '../../features/transactions/di/transactions_injection.dart';
import '../../features/users/di/users_injection.dart';

/// حاوية الاعتماديات المركزية (get_it).
final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // 0) Hive: التخزين المحلي المؤقت (ليس مصدرًا موثوقًا للأرصدة أو الصلاحيات).
  final hiveService = HiveService();
  await hiveService.init();
  await hiveService.openDefaultBoxes();

  // 1) تهيئة Firebase أولاً (Core + App Check + إعدادات Firestore).
  await FirebaseService.init();

  sl.registerLazySingleton(() => FirebaseService.auth);
  sl.registerLazySingleton(() => FirebaseService.firestore);
  sl.registerLazySingleton(() => FirebaseService.storage);

  // 2) الخدمات الأساسية المشتركة.
  sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
  // العمليات المالية الحساسة: بديل مجاني كامل لـ معاملات Firestore الذرية —
  // معاملات Firestore الذرية + تحقق كامل قبل الكتابة + قواعد أمان صارمة.
  sl.registerLazySingleton<FinancialOperationsService>(
    () => FinancialOperationsService(
      firestore: FirebaseService.firestore,
      auth: FirebaseService.auth,
    ),
  );
  sl.registerLazySingleton<HiveService>(() => hiveService);
  sl.registerLazySingleton<PendingOperationsService>(
    () => PendingOperationsService(
      connectivityService: sl<ConnectivityService>(),
      financialOperationsService: sl<FinancialOperationsService>(),
    ),
  );

  // 3) الميزات (تسجيل مستقل لكل ميزة).
  registerAuthFeature(sl);
  registerDashboardFeature(sl);
  registerCentersFeature(sl);
  registerBranchesFeature(sl);
  registerUsersFeature(sl);
  registerEnvelopesFeature(sl);
  registerTransactionsFeature(sl);
  registerEmployeeLoansFeature(sl);
  registerReportsFeature(sl);
  registerSettingsFeature(sl);
}
