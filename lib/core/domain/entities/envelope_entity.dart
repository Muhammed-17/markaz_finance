import 'package:equatable/equatable.dart';

import '../../constants/app_constants.dart';

/// كيان الظرف المالي — تقسيم تنظيمي للأموال حسب المصدر أو الغرض، وليس خزنة مستقلة.
class EnvelopeEntity extends Equatable {
  const EnvelopeEntity({
    required this.id,
    required this.name,
    required this.purpose,
    required this.fundType,
    required this.allowedExpenseCategories,
    required this.currentBalance,
    required this.centerId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String purpose;

  /// 'general' أو 'restricted'.
  final String fundType;

  /// تصنيفات المصروفات المسموح صرفها من هذا الظرف.
  final List<String> allowedExpenseCategories;

  /// الرصيد الحالي بالجنيه — المصدر الموثوق Firestore، والعميل يقرأه فقط.
  final num currentBalance;

  /// المركز المرتبط بالظرف عند الحاجة أو null.
  final String? centerId;

  /// 'active' أو 'archived'.
  final String status;
  final DateTime createdAt;

  bool get isGeneral => fundType == AppFundTypes.general;
  bool get isRestricted => fundType == AppFundTypes.restricted;
  bool get isActive => status == AppStatuses.active;
  bool get isArchived => status == AppStatuses.archived;

  /// هل يمكن صرف تصنيف معين من هذا الظرف؟
  /// القاعدة الآلية تعتمد على allowedExpenseCategories فقط للظروف المخصصة،
  /// وليس على الوصف النصي purpose.
  bool allowsExpenseCategory(String category) {
    if (!isActive) return false;
    if (isGeneral) return true;
    return allowedExpenseCategories.contains(category);
  }

  EnvelopeEntity copyWith({
    String? id,
    String? name,
    String? purpose,
    String? fundType,
    List<String>? allowedExpenseCategories,
    num? currentBalance,
    String? centerId,
    String? status,
    DateTime? createdAt,
  }) {
    return EnvelopeEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      purpose: purpose ?? this.purpose,
      fundType: fundType ?? this.fundType,
      allowedExpenseCategories:
          allowedExpenseCategories ?? this.allowedExpenseCategories,
      currentBalance: currentBalance ?? this.currentBalance,
      centerId: centerId ?? this.centerId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id, name, purpose, fundType, allowedExpenseCategories,
        currentBalance, centerId, status, createdAt,
      ];
}
