import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../domain/usecases/settings_usecases.dart';

part 'settings_state.dart';

/// Cubit الإعدادات: الملف الشخصي من AuthBloc، حالة الاتصال حيًا،
/// وتفضيلات العرض والمسح المؤقت من التخزين المحلي.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required ClearCacheUseCase clearCache,
    required GetDarkModePreference getDarkModePreference,
    required SaveDarkModePreference saveDarkModePreference,
    required ConnectivityService connectivityService,
    UserProfileEntity? initialProfile,
  })  : _clearCache = clearCache,
        _saveDarkModePreference = saveDarkModePreference,
        _connectivity = connectivityService,
        super(SettingsState(
          profile: initialProfile,
          isOnline: connectivityService.isOnline,
          // تفضيل عرض فقط — تنفيذ الثيم الداكن الفعلي في إصدار لاحق.
          isDarkMode: getDarkModePreference(),
        )) {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (online) {
        if (!isClosed) emit(state.copyWith(isOnline: online));
      },
    );
  }

  final ClearCacheUseCase _clearCache;
  final SaveDarkModePreference _saveDarkModePreference;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _connectivitySubscription;

  /// مزامنة الملف الشخصي مع حالة AuthBloc الحالية.
  void updateProfile(UserProfileEntity? profile) {
    if (state.profile == profile) return;
    emit(state.copyWith(profile: profile));
  }

  /// حفظ تفضيل الوضع الداكن (بدون تطبيق ثيم فعلي الآن).
  Future<void> toggleDarkMode(bool value) async {
    emit(state.copyWith(isDarkMode: value, clearMessage: true));
    final result = await _saveDarkModePreference(value);
    result.fold(
      (failure) {
        if (isClosed) return;
        // نعيد القيمة السابقة عند فشل الحفظ.
        emit(state.copyWith(
          isDarkMode: !value,
          status: SettingsStatus.preferenceFailure,
          message: 'تعذر حفظ تفضيل العرض، حاول مرة أخرى',
        ));
      },
      (_) {},
    );
  }

  /// مسح البيانات المؤقتة المحلية (المسودات وذاكرة التخزين المؤقت).
  Future<void> clearCache() async {
    emit(state.copyWith(
      status: SettingsStatus.cacheClearing,
      clearMessage: true,
    ));
    final result = await _clearCache();
    result.fold(
      (failure) {
        if (isClosed) return;
        emit(state.copyWith(
          status: SettingsStatus.cacheFailure,
          message: failure.message,
        ));
      },
      (_) {
        if (isClosed) return;
        emit(state.copyWith(
          status: SettingsStatus.cacheCleared,
          message: 'تم مسح البيانات المؤقتة بنجاح',
        ));
      },
    );
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
