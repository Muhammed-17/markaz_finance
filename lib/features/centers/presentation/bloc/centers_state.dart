part of 'centers_bloc.dart';

/// حالات شاشة المراكز.
enum CentersStatus {
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

final class CentersState extends Equatable {
  const CentersState({
    this.status = CentersStatus.initial,
    this.items = const [],
    this.searchQuery = '',
    this.isStale = false,
    this.cachedAt,
    this.failure,
    this.message,
  });

  final CentersStatus status;

  /// القائمة الكاملة المحملة من المستودع.
  final List<CenterEntity> items;

  /// نص البحث الحالي — التصفية محلية بالاسم.
  final String searchQuery;

  /// true عندما تعود القائمة من التخزين المؤقت بعد تعذر الشبكة.
  final bool isStale;
  final DateTime? cachedAt;
  final Failure? failure;
  final String? message;

  /// القائمة بعد تطبيق البحث المحلي على الاسم.
  List<CenterEntity> get filteredItems {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items
        .where((center) => center.name.toLowerCase().contains(query))
        .toList();
  }

  CentersState copyWith({
    CentersStatus? status,
    List<CenterEntity>? items,
    String? searchQuery,
    bool? isStale,
    DateTime? cachedAt,
    Failure? failure,
    bool clearFailure = false,
    String? message,
    bool clearMessage = false,
  }) {
    return CentersState(
      status: status ?? this.status,
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
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
        isStale,
        cachedAt,
        failure,
        message,
      ];
}
