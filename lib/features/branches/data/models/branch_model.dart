import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/branch_entity.dart';

/// نموذج الفرع للتحويل من وإلى Firestore والتخزين المؤقت.
/// الحقول مطابقة تمامًا لتصميم مجموعة branches — ممنوع إضافة أي حقل آخر:
/// centerId, name, location, createdAt, updatedAt فقط.
class BranchModel {
  const BranchModel({
    required this.id,
    required this.centerId,
    required this.name,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String centerId;
  final String name;
  final String location;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BranchModel.fromMap(String id, Map<String, dynamic> map) {
    return BranchModel(
      id: id,
      centerId: (map['centerId'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  factory BranchModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) =>
      BranchModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  /// تحويل بيانات Hive المخزنة مؤقتًا (خرائط بسيطة) إلى نموذج.
  factory BranchModel.fromCachedMap(Map<String, dynamic> map) =>
      BranchModel.fromMap((map['id'] ?? '') as String, map);

  /// تحويل طابع زمني من أي مصدر (Timestamp / DateTime / ميلي ثانية) إلى DateTime.
  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// خريطة القيم للعرض والتخزين المؤقت فقط.
  /// ملاحظة: الكتابة على Firestore تتم في مصدر البيانات مباشرةً
  /// عبر FieldValue.serverTimestamp — لا يُستخدم هذا الملف لكتابة مستندات.
  Map<String, dynamic> toMap() => {
        'centerId': centerId,
        'name': name,
        'location': location,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  /// خريطة التخزين المؤقت في Hive (تتضمن المعرّف).
  Map<String, dynamic> toCachedMap() => {
        'id': id,
        ...toMap(),
      };

  BranchEntity toEntity() => BranchEntity(
        id: id,
        centerId: centerId,
        name: name,
        location: location,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
