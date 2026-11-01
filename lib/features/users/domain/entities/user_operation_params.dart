import 'package:equatable/equatable.dart';

/// معاملات إنشاء مستخدم جديد — تُنفذ عبر عملية createUser الذرية
/// (التحقق الخادمي إلزامي وكلمة المرور لا تُخزن في أي مكان إطلاقًا).
class CreateUserParams extends Equatable {
  const CreateUserParams({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.isActive,
  });

  final String name;
  final String email;

  /// تمرر للخادم فقط عبر الدالة السحابية — ممنوع حفظها في Hive أو Firestore.
  final String password;

  /// 'admin' أو 'user' من AppRoles.
  final String role;

  final bool isActive;

  /// البيانات المرسلة إلى الدالة السحابية createUser.
  Map<String, dynamic> toCallableData() => {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'isActive': isActive,
      };

  @override
  List<Object?> get props => [
        name, email, role, isActive,
      ];
}

/// معاملات تعديل مستخدم قائم عبر عملية updateUser الذرية.
///
/// الحقول الاختيارية: فقط ما وُجد قيمته يُرسل إلى الخادم
/// (null تعني "لا تُعدّل هذا الحقل" وليس "اجعله فارغًا").
class UpdateUserParams extends Equatable {
  const UpdateUserParams({
    required this.userId,
    this.name,
    this.role,
    this.isActive,
  });

  final String userId;
  final String? name;
  final String? role;
  final bool? isActive;

  /// البيانات المرسلة إلى الدالة السحابية updateUser — المفاتيح الموجودة فقط.
  Map<String, dynamic> toCallableData() {
    final data = <String, dynamic>{'userId': userId};
    if (name != null) data['name'] = name;
    if (role != null) data['role'] = role;
    if (isActive != null) data['isActive'] = isActive;
    return data;
  }

  @override
  List<Object?> get props => [
        userId, name, role, isActive,
      ];
}
