import '../constants/app_constants.dart';
import '../domain/entities/user_entity.dart';

/// إجراءات الصلاحيات المالية المعتمدة.
enum PermissionAction { create, update, cancel, approve }

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

  /// التحقق من صلاحية مالية معينة للمستخدم.
  ///
  /// المدير يمتلك كل الصلاحيات ضمنيًا، وغيره وفق حقل financialPermissions.
  static bool can(UserProfileEntity? user, PermissionAction action) {
    if (user == null || !user.isActive) return false;
    if (user.role == AppRoles.admin) return true;
    switch (action) {
      case PermissionAction.create:
        return user.financialPermissions.create;
      case PermissionAction.update:
        return user.financialPermissions.update;
      case PermissionAction.cancel:
        return user.financialPermissions.cancel;
      case PermissionAction.approve:
        return user.financialPermissions.approve;
    }
  }

  /// أي من صلاحيتين متاحتين (اختصار للشروط المركبة).
  static bool canAny(UserProfileEntity? user, List<PermissionAction> actions) =>
      actions.any((a) => can(user, a));
}
