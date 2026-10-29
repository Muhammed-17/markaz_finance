import 'package:equatable/equatable.dart';

import '../../constants/app_constants.dart';

/// صلاحيات المستخدم المالية (مطابقة لحقل financialPermissions في Firestore).
class FinancialPermissions extends Equatable {
  const FinancialPermissions({
    this.view = false,
    this.create = false,
    this.update = false,
    this.cancel = false,
    this.approve = false,
  });

  final bool view;
  final bool create;
  final bool update;
  final bool cancel;
  final bool approve;

  const FinancialPermissions.all()
      : view = true,
        create = true,
        update = true,
        cancel = true,
        approve = true;

  const FinancialPermissions.none()
      : view = false,
        create = false,
        update = false,
        cancel = false,
        approve = false;

  factory FinancialPermissions.fromMap(Map<String, dynamic>? map) {
    bool flag(String key) => map?[key] == true;
    return FinancialPermissions(
      view: flag(AppPermissions.view),
      create: flag(AppPermissions.create),
      update: flag(AppPermissions.update),
      cancel: flag(AppPermissions.cancel),
      approve: flag(AppPermissions.approve),
    );
  }

  Map<String, dynamic> toMap() => {
        AppPermissions.view: view,
        AppPermissions.create: create,
        AppPermissions.update: update,
        AppPermissions.cancel: cancel,
        AppPermissions.approve: approve,
      };

  /// خريطة بقيم مفاتيح النص الخام (لإرسالها إلى الخادم دون تعديل التصميم).
  Map<String, bool> toRawMap() => toMap().map(
        (k, v) => MapEntry(k, v as bool),
      );

  @override
  List<Object?> get props => [view, create, update, cancel, approve];
}

/// كيان المستخدم — طبقة النطاق (Domain).
class UserProfileEntity extends Equatable {
  const UserProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.financialPermissions = const FinancialPermissions.none(),
    this.isActive = true,
  });

  final String id;
  final String name;
  final String email;

  /// 'admin' أو 'user' — قيمة نصية يتحقق منها الخادم.
  final String role;
  final FinancialPermissions financialPermissions;
  final bool isActive;

  bool get isAdmin => role == AppRoles.admin;
  bool get isUser => role == AppRoles.user;

  UserProfileEntity copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    FinancialPermissions? financialPermissions,
    bool? isActive,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      financialPermissions: financialPermissions ?? this.financialPermissions,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, email, role, financialPermissions, isActive];
}
