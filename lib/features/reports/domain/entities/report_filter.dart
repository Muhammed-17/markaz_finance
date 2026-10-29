import 'package:equatable/equatable.dart';

/// فلاتر تقرير مالي. القيم الفارغة تعني "بدون قيد".
///
/// ملاحظة الفهارس: الاستعلام الأساسي في المصدر يطبق فقط status + نطاق
/// createdAt، وبقية الفلاتر (type/category/centerId/envelopeId) تُطبَّق
/// على العميل بعد الجلب.
class ReportFilter extends Equatable {
  const ReportFilter({
    this.from,
    this.to,
    this.centerId,
    this.type,
    this.category,
    this.envelopeId,
    this.loanStatus,
  });

  /// بداية الفترة (شاملة) على تاريخ إنشاء الحركة.
  final DateTime? from;

  /// نهاية الفترة (شاملة) على تاريخ إنشاء الحركة.
  final DateTime? to;

  final String? centerId;

  /// 'income' أو 'expense' أو null (الكل).
  final String? type;

  /// تصنيف الحركة أو null (الكل).
  final String? category;

  /// الظرف المالي أو null (الكل).
  final String? envelopeId;

  /// فلتر حالة السلف المعروضة: 'active' أو 'paid_off' أو null (الكل).
  /// يستخدم لقسم السلف المرجعي فقط ولا يؤثر على الحسابات النقدية.
  final String? loanStatus;

  bool get isEmpty =>
      from == null &&
      to == null &&
      centerId == null &&
      type == null &&
      category == null &&
      envelopeId == null &&
      loanStatus == null;

  bool get hasPeriod => from != null || to != null;

  ReportFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? centerId,
    String? type,
    String? category,
    String? envelopeId,
    String? loanStatus,
  }) {
    return ReportFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      centerId: centerId ?? this.centerId,
      type: type ?? this.type,
      category: category ?? this.category,
      envelopeId: envelopeId ?? this.envelopeId,
      loanStatus: loanStatus ?? this.loanStatus,
    );
  }

  @override
  List<Object?> get props => [
        from, to, centerId, type, category, envelopeId, loanStatus,
      ];
}
