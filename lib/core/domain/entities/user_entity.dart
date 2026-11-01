import 'package:equatable/equatable.dart';

import '../../constants/app_constants.dart';

/// كيان المستخدم — طبقة النطاق (Domain).
class UserProfileEntity extends Equatable {
  const UserProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String email;

  /// 'admin' أو 'user' — قيمة نصية يتحقق منها الخادم.
  final String role;
  final bool isActive;

  bool get isAdmin => role == AppRoles.admin;
  bool get isUser => role == AppRoles.user;

  UserProfileEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    bool? isActive,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, email, role, isActive];
}
