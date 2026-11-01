import '../constants/app_constants.dart';
import '../domain/entities/user_entity.dart';

/// خدمة مركزية للتحقق من الصلاحيات في العميل (لعرض/إخفاء عناصر الواجهة).
///
/// قاعدة أساسية: هذا الفحص لتحسين تجربة الاستخدام فقط،
/// والمصدر الموثوق دائمًا هو التحقق الخادمي داخل معاملات Firestore الذرية وقواعد Firestore.
class PermissionService {
  const PermissionService._();

  /// هل المستخدم مدير؟
  static bool isAdmin(UserProfileEntity? user) =>
      user != null && user.role == AppRoles.admin && user.isActive;

  /// هل المستخدم نشط؟
  static bool isActive(UserProfileEntity? user) =>
      user != null && user.isActive;

  /// إضافة حركة مالية جديدة أو سلفة جديدة: متاحة لأي مستخدم نشط
  /// (مطابق لقواعد Firestore). بقية الإجراءات (تعديل الأظرف، إلغاء الحركات،
  /// التحويل بين الأظرف، إدارة المستخدمين) للمدير فقط.
  static bool canCreateEntries(UserProfileEntity? user) => isActive(user);

  /// سداد سلفة: مدير النظام، أو الموظف المُسلَّف نفسه (employeeId = uid).
  static bool canRepayLoan(UserProfileEntity? user, String? loanEmployeeId) =>
      isAdmin(user) ||
      (isActive(user) && loanEmployeeId != null && loanEmployeeId == user!.id);
}
