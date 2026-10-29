import 'package:get_it/get_it.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/services/hive_service.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/usecases/settings_usecases.dart';
import '../presentation/cubit/settings_cubit.dart';

/// تسجيل اعتماديات ميزة الإعدادات.
///
/// النمط المعتمد لكل الميزات:
/// void registerXxxFeature(GetIt sl) { ... }
void registerSettingsFeature(GetIt sl) {
  // Repository (العقد في domain والتنفيذ في data يلف HiveService)
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(hiveService: sl<HiveService>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => ClearCacheUseCase(sl<SettingsRepository>()));
  sl.registerLazySingleton(
      () => GetDarkModePreference(sl<SettingsRepository>()));
  sl.registerLazySingleton(
      () => SaveDarkModePreference(sl<SettingsRepository>()));

  // Cubit
  sl.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      clearCache: sl<ClearCacheUseCase>(),
      getDarkModePreference: sl<GetDarkModePreference>(),
      saveDarkModePreference: sl<SaveDarkModePreference>(),
      connectivityService: sl<ConnectivityService>(),
    ),
  );
}
