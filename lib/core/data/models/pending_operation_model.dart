import 'package:equatable/equatable.dart';

/// حالات المسودة المعلقة.
enum PendingOperationStatus {
  /// بانتظار توفر الإنترنت
  pending,

  /// جارٍ إرسالها إلى الخادم الآن
  syncing,

  /// رُفضت من الخادم (مثال: تعارض رصيد، أو سُددت بالفعل)
  failed,
}

/// نموذج العملية المعلقة للتخزين في Hive عند العمل بدون اتصال.
class PendingOperationModel extends Equatable {
  const PendingOperationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.payload,
    required this.createdAt,
    this.status = PendingOperationStatus.pending,
    this.failureReason,
  });

  /// معرف محلي فريد للعملية
  final String id;

  /// اسم العملية المتوافق مع AppFunctions (مثل: repayLoan, createEmployeeLoan)
  final String type;

  /// عنوان مقروء يوضح للمستخدم ما هي هذه العملية
  final String title;

  /// بيانات العملية الكاملة الموجهة للخادم
  final Map<String, dynamic> payload;

  /// وقت حفظ المسودة
  final DateTime createdAt;

  /// حالة المسودة
  final PendingOperationStatus status;

  /// سبب الفشل أو الرفض من الخادم إن وُجد
  final String? failureReason;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'title': title,
        'payload': payload,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'status': status.name,
        'failureReason': failureReason,
      };

  factory PendingOperationModel.fromMap(Map<String, dynamic> map) {
    return PendingOperationModel(
      id: map['id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      status: PendingOperationStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PendingOperationStatus.pending,
      ),
      failureReason: map['failureReason'] as String?,
    );
  }

  PendingOperationModel copyWith({
    PendingOperationStatus? status,
    String? failureReason,
    bool clearFailureReason = false,
  }) {
    return PendingOperationModel(
      id: id,
      type: type,
      title: title,
      payload: payload,
      createdAt: createdAt,
      status: status ?? this.status,
      failureReason:
          clearFailureReason ? null : (failureReason ?? this.failureReason),
    );
  }

  @override
  List<Object?> get props =>
      [id, type, title, payload, createdAt, status, failureReason];
}
