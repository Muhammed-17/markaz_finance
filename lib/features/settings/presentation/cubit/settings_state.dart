part of 'settings_cubit.dart';

/// حالات شاشة الإعدادات.
enum SettingsStatus {
  initial,

  /// جارٍ مسح البيانات المؤقتة.
  cacheClearing,

  /// تم المسح بنجاح.
  cacheCleared,

  /// فشل مسح البيانات المؤقتة.
  cacheFailure,

  /// فشل حفظ تفضيل العرض.
  preferenceFailure,
}

final class SettingsState extends Equatable {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.profile,
    this.isOnline = true,
    this.isDarkMode = false,
    this.message,
  });

  final SettingsStatus status;

  /// الملف الشخصي الحالي (الاسم/البريد/الدور/الصلاحيات) من AuthBloc.
  final UserProfileEntity? profile;

  /// حالة الاتصال بالشبكة — بث حي من ConnectivityService.
  final bool isOnline;

  /// تفضيل الوضع الداكن المحفوظ محليًا فقط
  /// (تنفيذ الثيم الداكن الفعلي في إصدار لاحق).
  final bool isDarkMode;

  final String? message;

  bool get isBusy => status == SettingsStatus.cacheClearing;

  SettingsState copyWith({
    SettingsStatus? status,
    UserProfileEntity? profile,
    bool? isOnline,
    bool? isDarkMode,
    String? message,
    bool clearMessage = false,
  }) {
    return SettingsState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      isOnline: isOnline ?? this.isOnline,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [
        status, profile, isOnline, isDarkMode, message,
      ];
}
