import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/models/user_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/financial_operations_service.dart';
import '../../domain/entities/user_operation_params.dart';

/// مصدر بيانات المستخدمين البعيد.
///
/// قواعد صارمة:
/// - القراءة مباشرة من مجموعة users في Firestore (المدير فقط يملك الصلاحية
///   وفق القواعد، والفرز بالاسم يتم على العميل).
/// - الإنشاء والتعديل حصرًا عبر [FinancialOperationsService]:
///   إنشاء الحساب عبر نسخة Firebase ثانوية (بدل Admin SDK المدفوع)،
///   وتعديل المستند مباشرة بقيود قواعد الأمان.
/// - كلمة المرور تمر لخدمة المصادقة فقط ولا تُخزن في أي مكان.
class UsersRemoteDataSource {
  UsersRemoteDataSource({
    required FirebaseFirestore firestore,
    required FinancialOperationsService operations,
  })  : _firestore = firestore,
        _operations = operations;

  final FirebaseFirestore _firestore;
  final FinancialOperationsService _operations;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppCollections.users);

  /// بث حي لمستندات users مع الفرز بالاسم على العميل.
  Stream<List<UserModel>> watchUsers() {
    return _users.snapshots().map((snapshot) {
      final models =
          snapshot.docs.map(UserModel.fromSnapshot).toList();
      models.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return models;
    });
  }

  /// إنشاء مستخدم عبر العملية createUser — يُرجع معرف المستخدم الجديد
  /// (حساب المصادقة يُنشأ عبر نسخة Firebase ثانوية دون التأثير على جلسة المدير).
  Future<String> createUser(CreateUserParams params) async {
    final result =
        await _operations.call(AppFunctions.createUser, params.toCallableData());
    final userId = result['userId'];
    if (userId is String && userId.isNotEmpty) return userId;
    throw const ServerException('تعذر إنشاء المستخدم، حاول مرة أخرى');
  }

  /// تعديل مستخدم قائم عبر العملية updateUser.
  Future<void> updateUser(UpdateUserParams params) async {
    await _operations.call(AppFunctions.updateUser, params.toCallableData());
  }
}
