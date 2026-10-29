import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_operation_params.dart';
import '../../domain/usecases/users_usecases.dart';

part 'users_event.dart';
part 'users_state.dart';

/// Bloc إدارة المستخدمين — للمديرين فقط.
///
/// القائمة تُبث حيًا من Firestore؛ عمليات الإنشاء والتعديل تمر عبر
/// العمليات الذرية والقائمة تُحدَّث تلقائيًا من البث.
class UsersBloc extends Bloc<UsersEvent, UsersState> {
  UsersBloc({
    required WatchUsers watchUsers,
    required CreateUser createUser,
    required UpdateUser updateUser,
  })  : _watchUsers = watchUsers,
        _createUser = createUser,
        _updateUser = updateUser,
        super(const UsersState()) {
    on<UsersLoadRequested>(_onLoadRequested, transformer: droppable());
    on<UsersCollectionUpdated>(_onCollectionUpdated);
    on<UsersCollectionFailed>(_onCollectionFailed);
    on<UsersSearchQueryChanged>(_onSearchQueryChanged);
    on<UsersRoleFilterChanged>(_onRoleFilterChanged);
    on<UsersCreateUserRequested>(_onCreateUserRequested,
        transformer: droppable());
    on<UsersUpdateUserRequested>(_onUpdateUserRequested,
        transformer: droppable());
  }

  final WatchUsers _watchUsers;
  final CreateUser _createUser;
  final UpdateUser _updateUser;

  StreamSubscription<List<UserProfileEntity>>? _usersSubscription;

  /// بدء/إعادة بدء البث الحي لقائمة المستخدمين.
  Future<void> _onLoadRequested(
    UsersLoadRequested event,
    Emitter<UsersState> emit,
  ) async {
    await _usersSubscription?.cancel();
    _usersSubscription = null;
    emit(state.copyWith(
      status: state.users.isEmpty ? UsersStatus.loading : state.status,
      clearFailure: true,
      clearMessage: true,
    ));

    _usersSubscription = _watchUsers().listen(
      (users) {
        if (!isClosed) add(UsersCollectionUpdated(users));
      },
      onError: (Object e) {
        if (!isClosed) {
          add(UsersCollectionFailed(
            e is Failure ? e : ErrorHandler.handle(e),
          ));
        }
      },
    );
  }

  /// وصول بيانات جديدة من البث الحي.
  void _onCollectionUpdated(
    UsersCollectionUpdated event,
    Emitter<UsersState> emit,
  ) {
    final users = event.users;

    // أثناء عملية إرسال جارية نحدّث القائمة بصمت دون تغيير الحالة.
    if (state.status == UsersStatus.submitting) {
      emit(state.copyWith(users: users));
      return;
    }

    emit(UsersState(
      status: users.isEmpty ? UsersStatus.empty : UsersStatus.success,
      users: users,
      searchQuery: state.searchQuery,
      roleFilter: state.roleFilter,
    ));
  }

  /// فشل قراءة القائمة (صلاحية/شبكة) — يظهر Failure برسالة عربية.
  void _onCollectionFailed(
    UsersCollectionFailed event,
    Emitter<UsersState> emit,
  ) {
    emit(UsersState(
      status: UsersStatus.failure,
      failure: event.failure,
      searchQuery: state.searchQuery,
      roleFilter: state.roleFilter,
    ));
  }

  void _onSearchQueryChanged(
    UsersSearchQueryChanged event,
    Emitter<UsersState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onRoleFilterChanged(
    UsersRoleFilterChanged event,
    Emitter<UsersState> emit,
  ) {
    emit(state.copyWith(roleFilter: event.filter));
  }

  /// إنشاء مستخدم جديد عبر الدالة السحابية.
  Future<void> _onCreateUserRequested(
    UsersCreateUserRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(
      status: UsersStatus.submitting,
      clearFailure: true,
      clearMessage: true,
    ));
    final result = await _createUser(event.params);
    result.fold(
      (failure) => emit(state.copyWith(
        status: UsersStatus.operationFailure,
        failure: failure,
        message: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: UsersStatus.operationCompleted,
        message: 'تم إنشاء المستخدم بنجاح',
      )),
    );
  }

  /// تعديل مستخدم قائم (الاسم/الدور/الصلاحيات/التفعيل) عبر الدالة السحابية.
  Future<void> _onUpdateUserRequested(
    UsersUpdateUserRequested event,
    Emitter<UsersState> emit,
  ) async {
    emit(state.copyWith(
      status: UsersStatus.submitting,
      clearFailure: true,
      clearMessage: true,
    ));
    final result = await _updateUser(event.params);
    result.fold(
      (failure) => emit(state.copyWith(
        status: UsersStatus.operationFailure,
        failure: failure,
        message: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: UsersStatus.operationCompleted,
        message: 'تم تحديث بيانات المستخدم بنجاح',
      )),
    );
  }

  @override
  Future<void> close() {
    _usersSubscription?.cancel();
    return super.close();
  }
}
