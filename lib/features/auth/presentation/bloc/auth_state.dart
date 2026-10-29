part of 'auth_bloc.dart';

/// حالات المصادقة.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// حالة غير معروفة بعد (الإقلاع).
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// جارٍ تسجيل الدخول.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// مستخدم مسجل الدخول.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.profile);

  final UserProfileEntity profile;

  @override
  List<Object?> get props => [profile];
}

/// غير مسجل الدخول.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// فشل تسجيل الدخول.
final class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
