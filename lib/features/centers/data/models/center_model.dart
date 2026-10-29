import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/center_entity.dart';

/// نموذج المركز للتحويل من وإلى Firestore والتخزين المؤقت.
/// الحقول مطابقة تمامًا لتصميم مجموعة centers — ممنوع إضافة أي حقل آخر:
/// name, description, createdAt, updatedAt فقط.
class CenterModel {
  const CenterModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CenterModel.fromMap(String id, Map<String, dynamic> map) {
    return CenterModel(
      id: id,
      name: (map['name'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  factory CenterModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) =>
      CenterModel.fromMap(doc.id, doc.data() ?? <String, dynamic>{});

  /// تحويل بيانات Hive المخزنة مؤقتًا (خرائط بسيطة) إلى نموذج.
  factory CenterModel.fromCachedMap(Map<String, dynamic> map) =>
      CenterModel.fromMap((map['id'] ?? '') as String, map);

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
        'name': name,
        'description': description,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  /// خريطة التخزين المؤقت في Hive (تتضمن المعرّف).
  Map<String, dynamic> toCachedMap() => {
        'id': id,
        ...toMap(),
      };

  CenterEntity toEntity() => CenterEntity(
        id: id,
        name: name,
        description: description,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
