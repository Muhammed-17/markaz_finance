import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';

/// نموذج المستخدم للتحويل من وإلى Firestore.
/// الحقول مطابقة لتصميم مجموعة users تمامًا (بدون حقول زمنية إضافية).
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.financialPermissions,
    required this.isActive,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final Map<String, dynamic> financialPermissions;
  final bool isActive;

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      role: (map['role'] ?? '') as String,
      financialPermissions:
          Map<String, dynamic>.from(
              (map['financialPermissions'] as Map?) ?? <String, dynamic>{}),
      isActive: (map['isActive'] ?? true) as bool,
    );
  }

  factory UserModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  /// تحويل بيانات Hive المخزنة مؤقتًا (خرائط بسيطة) إلى نموذج.
  factory UserModel.fromCachedMap(Map<String, dynamic> map) => UserModel.fromMap(
        (map['id'] ?? '') as String,
        map,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role,
        'financialPermissions': financialPermissions,
        'isActive': isActive,
      };

  Map<String, dynamic> toCachedMap() => {
        'id': id,
        ...toMap(),
      };

  UserProfileEntity toEntity() => UserProfileEntity(
        id: id,
        name: name,
        email: email,
        role: role,
        financialPermissions: FinancialPermissions.fromMap(financialPermissions),
        isActive: isActive,
      );
}
