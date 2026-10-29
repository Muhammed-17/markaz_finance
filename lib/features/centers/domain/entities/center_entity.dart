import 'package:equatable/equatable.dart';

/// كيان المركز — طبقة النطاق (بلا أي اعتماد على Flutter/Firebase/Hive).
class CenterEntity extends Equatable {
  const CenterEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// الوصف اختياري — قد يكون نصًا فارغًا.
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, name, description, createdAt, updatedAt];
}

/// نتيجة جلب قائمة المراكز مع علم البيانات القديمة.
///
/// [isStale] = true يعني أن القائمة قادمة من التخزين المحلي المؤقت
/// بعد تعذر الوصول للشبكة، ويجب تنبيه المستخدم في الواجهة.
class CentersResult {
  const CentersResult({
    required this.items,
    this.isStale = false,
    this.cachedAt,
  });

  final List<CenterEntity> items;
  final bool isStale;
  final DateTime? cachedAt;
}
