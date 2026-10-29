part of 'branches_bloc.dart';

/// أحداث شاشة الفروع.
sealed class BranchesEvent extends Equatable {
  const BranchesEvent();

  @override
  List<Object?> get props => [];
}

/// طلب تحميل/تحديث قائمة الفروع.
/// إن مُرِّر [centerId] يُستبدل به فلتر المركز الحالي،
/// وإلا يُستخدم الفلتر الحالي (null يعني كل المراكز).
final class BranchesLoadRequested extends BranchesEvent {
  const BranchesLoadRequested({this.centerId});

  final String? centerId;

  @override
  List<Object?> get props => [centerId];
}

/// تغيير فلتر المركز (null = الكل) ثم إعادة التحميل.
final class BranchesCenterFilterChanged extends BranchesEvent {
  const BranchesCenterFilterChanged(this.centerId);

  final String? centerId;

  @override
  List<Object?> get props => [centerId];
}

/// تغيير نص البحث — التصفية تتم محليًا على القائمة المحملة.
final class BranchesSearchQueryChanged extends BranchesEvent {
  const BranchesSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// طلب إضافة فرع جديد تابع لمركز.
final class BranchesAddRequested extends BranchesEvent {
  const BranchesAddRequested({
    required this.centerId,
    required this.name,
    this.location,
  });

  final String centerId;
  final String name;
  final String? location;

  @override
  List<Object?> get props => [centerId, name, location];
}

/// طلب تعديل فرع موجود.
final class BranchesUpdateRequested extends BranchesEvent {
  const BranchesUpdateRequested({
    required this.id,
    required this.centerId,
    required this.name,
    this.location,
  });

  final String id;
  final String centerId;
  final String name;
  final String? location;

  @override
  List<Object?> get props => [id, centerId, name, location];
}
