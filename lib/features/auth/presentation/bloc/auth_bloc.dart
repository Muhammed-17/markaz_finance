import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/user_entity.dart';
import '../../domain/usecases/auth_usecases.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Bloc المصادقة المركزي — يُنشأ على مستوى التطبيق.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required ObserveAuthProfile observeAuthProfile,
    required SignInUseCase signIn,
    required SignInWithGoogleUseCase signInWithGoogle,
    required SignOutUseCase signOut,
  })  : _observeAuthProfile = observeAuthProfile,
        _signIn = signIn,
        _signInWithGoogle = signInWithGoogle,
        _signOut = signOut,
        super(const AuthUnknown()) {
    on<AuthStarted>(_onStarted, transformer: droppable());
    on<AuthProfileChanged>(_onProfileChanged);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested,
        transformer: droppable());
    on<AuthSignOutRequested>(_onSignOutRequested, transformer: droppable());

    add(const AuthStarted());
  }

  final ObserveAuthProfile _observeAuthProfile;
  final SignInUseCase _signIn;
  final SignInWithGoogleUseCase _signInWithGoogle;
  final SignOutUseCase _signOut;

  StreamSubscription<dynamic>? _profileSubscription;

  Future<void> _onStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    await _profileSubscription?.cancel();
    _profileSubscription = _observeAuthProfile().listen((profile) {
      add(AuthProfileChanged(profile));
    });
  }

  void _onProfileChanged(
    AuthProfileChanged event,
    Emitter<AuthState> emit,
  ) {
    final profile = event.profile;
    if (profile == null || !profile.isActive) {
      emit(const AuthUnauthenticated());
    } else {
      emit(AuthAuthenticated(profile));
    }
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _signIn(
      email: event.email,
      password: event.password,
    );
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (profile) => emit(AuthAuthenticated(profile)),
    );
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _signInWithGoogle();
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (profile) => emit(AuthAuthenticated(profile)),
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _signOut();
    // الحالة الفعلية ستأتي من بث المصادقة (AuthProfileChanged).
  }

  @override
  Future<void> close() {
    _profileSubscription?.cancel();
    return super.close();
  }
}
