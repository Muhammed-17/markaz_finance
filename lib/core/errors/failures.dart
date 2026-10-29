import 'package:equatable/equatable.dart';

/// حالات الفشل المعروضة للواجهة — عربية ومفهومة للمستخدم،
/// مع الاحتفاظ بالتفاصيل التقنية للسجلات دون عرضها.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code, this.technicalDetails});

  final String message;
  final String? code;
  final String? technicalDetails;

  @override
  List<Object?> get props => [message, code, technicalDetails];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code, super.technicalDetails});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

class UnauthenticatedFailure extends Failure {
  const UnauthenticatedFailure([super.message = 'يجب تسجيل الدخول أولًا']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'لا تمتلك الصلاحية لتنفيذ هذه العملية',
  ]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'تعذر الاتصال بالشبكة، تحقق من اتصالك وحاول مرة أخرى',
  ]);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message, {super.technicalDetails});
}

class OperationRejectedFailure extends Failure {
  const OperationRejectedFailure(super.message, {super.code});
}

class ConflictFailure extends Failure {
  const ConflictFailure([
    super.message = 'تم تعديل هذا السجل من مستخدم آخر، حدّث البيانات وأعد المحاولة',
  ]);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'حدث خطأ غير متوقع، حاول مرة أخرى لاحقًا',
    String? technicalDetails,
  ]) : super(technicalDetails: technicalDetails);
}
