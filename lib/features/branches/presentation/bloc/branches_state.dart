part of 'branches_bloc.dart';

/// حالات شاشة الفروع.
enum BranchesStatus {
  initial,
  loading,
  refreshing,
  success,
  empty,
  failure,
  submitting,
  operationCompleted,
  operationFailure,
}

final class BranchesState extends Equatable {
  const BranchesState({
    this.status = BranchesStatus.initial,
    this.items = const [],
    this.searchQuery = '',
    this.selectedCenterId,
    this.isStale = false,
    this.cachedAt,
    this.failure,
    this.message,
  });

  final BranchesStatus status;

  /// القائمة الكاملة المحملة من المستودع (مرتبة بالاسم).
  final List<BranchEntity> items;

  /// نص البحث الحالي — التصفية محلية بالاسم.
  final String searchQuery;

  /// فلتر المركز الحالي (null = كل المراكز).
  final String? selectedCenterId;

  /// true عندما تعود القائمة من التخزين المؤقت بعد تعذر الشبكة.
  final bool isStale;
  final DateTime? cachedAt;
  final Failure? failure;
  final String? message;

  /// القائمة بعد تطبيق البحث المحلي على الاسم.
  List<BranchEntity> get filteredItems {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where((branch) => branch.name.toLowerCase().contains(query))
        .toList();
  }

  BranchesState copyWith({
    BranchesStatus? status,
    List<BranchEntity>? items,
    String? searchQuery,
    String? selectedCenterId,
    bool clearSelectedCenter = false,
    bool? isStale,
    DateTime? cachedAt,
    Failure? failure,
    bool clearFailure = false,
    String? message,
    bool clearMessage = false,
  }) {
    return BranchesState(
      status: status ?? this.status,
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCenterId:
          clearSelectedCenter ? null : (selectedCenterId ?? this.selectedCenterId),
      isStale: isStale ?? this.isStale,
      cachedAt: cachedAt ?? this.cachedAt,
      failure: clearFailure ? null : (failure ?? this.failure),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        searchQuery,
        selectedCenterId,
        isStale,
        cachedAt,
        failure,
        message,
      ];
}
