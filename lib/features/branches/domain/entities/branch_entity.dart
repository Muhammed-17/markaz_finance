import 'package:equatable/equatable.dart';

/// كيان الفرع — طبقة النطاق (بلا أي اعتماد على Flutter/Firebase/Hive).
/// كل فرع يتبع مركزًا ([centerId] مطلوب).
class BranchEntity extends Equatable {
  const BranchEntity({
    required this.id,
    required this.centerId,
    required this.name,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// معرّف المركز التابع له الفرع.
  final String centerId;
  final String name;

  /// الموقع اختياري — قد يكون نصًا فارغًا.
  final String location;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props =>
      [id, centerId, name, location, createdAt, updatedAt];
}

/// نتيجة جلب قائمة الفروع مع علم البيانات القديمة.
///
/// [isStale] = true يعني أن القائمة قادمة من التخزين المحلي المؤقت
/// بعد تعذر الوصول للشبكة، ويجب تنبيه المستخدم في الواجهة.
class BranchesResult {
  const BranchesResult({
    required this.items,
    this.isStale = false,
    this.cachedAt,
  });

  final List<BranchEntity> items;
  final bool isStale;
  final DateTime? cachedAt;
}
