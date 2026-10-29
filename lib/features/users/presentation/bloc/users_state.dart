part of 'users_bloc.dart';

/// فلتر الدور في قائمة المستخدمين.
enum UsersRoleFilter { all, admins, users }

/// حالات شاشة إدارة المستخدمين.
enum UsersStatus {
  initial,
  loading,
  success,
  empty,
  failure,
  submitting,
  operationCompleted,
  operationFailure,
}

final class UsersState extends Equatable {
  const UsersState({
    this.status = UsersStatus.initial,
    this.users = const [],
    this.searchQuery = '',
    this.roleFilter = UsersRoleFilter.all,
    this.failure,
    this.message,
  });

  final UsersStatus status;

  /// كل المستخدمين الواردة من البث الحي.
  final List<UserProfileEntity> users;

  /// نص البحث (الاسم أو البريد الإلكتروني).
  final String searchQuery;
  final UsersRoleFilter roleFilter;

  final Failure? failure;
  final String? message;

  /// المستخدمون بعد تطبيق البحث وفلتر الدور.
  List<UserProfileEntity> get visibleUsers {
    final query = searchQuery.trim().toLowerCase();
    return users.where((user) {
      final matchesFilter = switch (roleFilter) {
        UsersRoleFilter.all => true,
        UsersRoleFilter.admins => user.isAdmin,
        UsersRoleFilter.users => user.isUser,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
  }

  UsersState copyWith({
    UsersStatus? status,
    List<UserProfileEntity>? users,
    String? searchQuery,
    UsersRoleFilter? roleFilter,
    Failure? failure,
    String? message,
    bool clearFailure = false,
    bool clearMessage = false,
  }) {
    return UsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilter: roleFilter ?? this.roleFilter,
      failure: clearFailure ? null : (failure ?? this.failure),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [
        status, users, searchQuery, roleFilter, failure, message,
      ];
}
