part of 'users_bloc.dart';

/// أحداث إدارة المستخدمين.
sealed class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

/// طلب بدء/إعادة بدء بث قائمة المستخدمين.
final class UsersLoadRequested extends UsersEvent {
  const UsersLoadRequested();
}

/// وصول قائمة محدثة من البث الحي (حدث داخلي).
final class UsersCollectionUpdated extends UsersEvent {
  const UsersCollectionUpdated(this.users);

  final List<UserProfileEntity> users;

  @override
  List<Object?> get props => [users];
}

/// فشل قراءة القائمة من البث (حدث داخلي).
final class UsersCollectionFailed extends UsersEvent {
  const UsersCollectionFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// تغيير نص البحث (بالاسم أو البريد الإلكتروني).
final class UsersSearchQueryChanged extends UsersEvent {
  const UsersSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// تغيير فلتر الدور (الكل/مدير/مستخدم).
final class UsersRoleFilterChanged extends UsersEvent {
  const UsersRoleFilterChanged(this.filter);

  final UsersRoleFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// طلب إنشاء مستخدم جديد عبر الدالة السحابية.
final class UsersCreateUserRequested extends UsersEvent {
  const UsersCreateUserRequested(this.params);

  final CreateUserParams params;

  @override
  List<Object?> get props => [params];
}

/// طلب تعديل مستخدم قائم عبر الدالة السحابية.
final class UsersUpdateUserRequested extends UsersEvent {
  const UsersUpdateUserRequested(this.params);

  final UpdateUserParams params;

  @override
  List<Object?> get props => [params];
}
