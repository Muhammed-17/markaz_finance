part of 'envelopes_bloc.dart';

/// حالات شاشة الأظرف المالية.
enum EnvelopesStatus {
  initial,
  loading,
  refreshing,
  success,
  failure,
  submitting,
  operationCompleted,
  operationFailure,
}

final class EnvelopesState extends Equatable {
  const EnvelopesState({
    this.status = EnvelopesStatus.initial,
    this.items = const [],
    this.searchQuery = '',
    this.failure,
    this.message,
    this.messageToken = 0,
    this.lastOperation = EnvelopesOperation.none,
  });

  final EnvelopesStatus status;
  final List<EnvelopeEntity> items;
  final String searchQuery;
  final Failure? failure;

  /// رسالة آخر عملية (نجاح أو فشل) — ترافقها [messageToken]
  /// لضمان إطلاق تنبيه جديد حتى تكررت الرسالة نفسها.
  final String? message;
  final int messageToken;
  final EnvelopesOperation lastOperation;

  List<EnvelopeEntity> get activeEnvelopes =>
      items.where((e) => e.isActive).toList();

  List<EnvelopeEntity> get archivedEnvelopes =>
      items.where((e) => e.isArchived).toList();

  /// القائمة الظاهرة وفق تبويب النشطة/المؤرشفة ونص البحث.
  List<EnvelopeEntity> visibleEnvelopes({required bool showArchived}) {
    final source = showArchived ? archivedEnvelopes : activeEnvelopes;
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source
        .where((e) =>
            e.name.toLowerCase().contains(query) ||
            e.purpose.toLowerCase().contains(query))
        .toList();
  }

  bool get isSubmitting => status == EnvelopesStatus.submitting;

  EnvelopesState copyWith({
    EnvelopesStatus? status,
    List<EnvelopeEntity>? items,
    String? searchQuery,
    Failure? failure,
    String? message,
    int? messageToken,
    EnvelopesOperation? lastOperation,
    bool clearFailure = false,
    bool clearMessage = false,
  }) {
    return EnvelopesState(
      status: status ?? this.status,
      items: items ?? this.items,
      searchQuery: searchQuery ?? this.searchQuery,
      failure: clearFailure ? null : (failure ?? this.failure),
      message: clearMessage ? null : (message ?? this.message),
      messageToken: messageToken ?? this.messageToken,
      lastOperation: lastOperation ?? this.lastOperation,
    );
  }

  @override
  List<Object?> get props => [
        status, items, searchQuery, failure, message, messageToken,
        lastOperation,
      ];
}
