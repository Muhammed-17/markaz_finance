part of 'centers_bloc.dart';

/// أحداث شاشة المراكز.
sealed class CentersEvent extends Equatable {
  const CentersEvent();

  @override
  List<Object?> get props => [];
}

/// طلب تحميل/تحديث قائمة المراكز.
final class CentersLoadRequested extends CentersEvent {
  const CentersLoadRequested();
}

/// تغيير نص البحث — التصفية تتم محليًا على القائمة المحملة.
final class CentersSearchQueryChanged extends CentersEvent {
  const CentersSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// طلب إضافة مركز جديد.
final class CentersAddRequested extends CentersEvent {
  const CentersAddRequested({required this.name, this.description});

  final String name;
  final String? description;

  @override
  List<Object?> get props => [name, description];
}

/// طلب تعديل مركز موجود.
final class CentersUpdateRequested extends CentersEvent {
  const CentersUpdateRequested({
    required this.id,
    required this.name,
    this.description,
  });

  final String id;
  final String name;
  final String? description;

  @override
  List<Object?> get props => [id, name, description];
}
