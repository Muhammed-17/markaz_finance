/// مرجع مبسط لمركز — يُستخدم في الفلاتر والنماذج بدلاً من كيان المركز الكامل.
///
/// يُجلب من مجموعة centers بترتيب الاسم ولا يحمل أي بيانات مالية حساسة.
class CenterRef {
  const CenterRef({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  @override
  String toString() => 'CenterRef(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CenterRef &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
