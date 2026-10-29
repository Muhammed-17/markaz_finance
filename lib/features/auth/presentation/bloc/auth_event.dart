part of 'auth_bloc.dart';

/// أحداث المصادقة.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// بدء مراقبة حالة المصادقة.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// تغير الملف الشخصي من البث الموثوق.
final class AuthProfileChanged extends AuthEvent {
  const AuthProfileChanged(this.profile);

  final UserProfileEntity? profile;

  @override
  List<Object?> get props => [profile];
}

/// طلب تسجيل دخول.
final class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// طلب تسجيل الدخول بحساب Google.
final class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

/// طلب تسجيل خروج.
final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
