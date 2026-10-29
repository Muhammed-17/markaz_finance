part of 'envelopes_bloc.dart';

/// أحداث ميزة الأظرف المالية.
sealed class EnvelopesEvent extends Equatable {
  const EnvelopesEvent();

  @override
  List<Object?> get props => [];
}

/// طلب بدء/تحديث بث الأظرف.
final class EnvelopesLoadRequested extends EnvelopesEvent {
  const EnvelopesLoadRequested();
}

/// تغيير نص البحث (على الاسم والغرض — تصفية محلية).
final class EnvelopesSearchQueryChanged extends EnvelopesEvent {
  const EnvelopesSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// طلب إنشاء ظرف مالي.
final class EnvelopesCreateRequested extends EnvelopesEvent {
  const EnvelopesCreateRequested(this.params);

  final EnvelopeFormParams params;

  @override
  List<Object?> get props => [params];
}

/// طلب تعديل بيانات ظرف.
final class EnvelopesUpdateRequested extends EnvelopesEvent {
  const EnvelopesUpdateRequested(this.params);

  final UpdateEnvelopeParams params;

  @override
  List<Object?> get props => [params];
}

/// طلب أرشفة أو إعادة تنشيط ظرف.
final class EnvelopesArchiveRequested extends EnvelopesEvent {
  const EnvelopesArchiveRequested({
    required this.envelopeId,
    required this.archive,
  });

  final String envelopeId;

  /// true = أرشفة، false = إعادة تنشيط.
  final bool archive;

  @override
  List<Object?> get props => [envelopeId, archive];
}

/// طلب تحويل مبلغ بين ظرفين.
final class EnvelopesTransferRequested extends EnvelopesEvent {
  const EnvelopesTransferRequested(this.transferParams);

  final TransferParams transferParams;

  @override
  List<Object?> get props => [transferParams];
}
