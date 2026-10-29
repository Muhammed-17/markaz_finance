/// النصوص المركزية المشتركة للتطبيق (عربية).
/// ويجري هنا فقط ما هو مشترك بين الميزات.
abstract final class AppStrings {
  // ================= عام =================
  static const String appName = 'نظام إدارة مراكز تحفيظ القرآن الكريم';
  static const String appNameShort = 'مراكز التحفيظ';
  static const String appSubtitle = 'النظام المالي والإداري';
  static const String loading = 'جارٍ التحميل...';
  static const String retry = 'إعادة المحاولة';
  static const String cancel = 'إلغاء';
  static const String save = 'حفظ';
  static const String edit = 'تعديل';
  static const String delete = 'حذف';
  static const String add = 'إضافة';
  static const String confirm = 'تأكيد';
  static const String back = 'رجوع';
  static const String search = 'بحث';
  static const String filter = 'تصفية';
  static const String clearFilters = 'مسح التصفية';
  static const String all = 'الكل';
  static const String details = 'التفاصيل';
  static const String notes = 'ملاحظات';
  static const String name = 'الاسم';
  static const String description = 'الوصف';
  static const String amount = 'المبلغ';
  static const String date = 'التاريخ';
  static const String status = 'الحالة';
  static const String type = 'النوع';
  static const String category = 'التصنيف';
  static const String actions = 'إجراءات';
  static const String none = 'بدون';
  static const String notAvailable = '—';
  static const String operationSuccess = 'تم تنفيذ العملية بنجاح';
  static const String confirmAction = 'تأكيد العملية';
  static const String requiredField = 'هذا الحقل مطلوب';

  // ================= المصادقة =================
  static const String loginTitle = 'تسجيل الدخول';
  static const String loginSubtitle =
      'أدخل بيانات حسابك للوصول إلى النظام المالي والإداري';
  static const String email = 'البريد الإلكتروني';
  static const String password = 'كلمة المرور';
  static const String signIn = 'دخول';
  static const String signOut = 'تسجيل الخروج';
  static const String signingIn = 'جارٍ تسجيل الدخول...';
  static const String signOutConfirm =
      'هل تريد تسجيل الخروج من النظام؟ سيتم مسح البيانات المؤقتة المحلية.';

  // ================= التنقل =================
  static const String navDashboard = 'لوحة التحكم';
  static const String navTransactions = 'الحركات المالية';
  static const String navLoans = 'سلف الموظفين';
  static const String navEnvelopes = 'الأظرف المالية';
  static const String navCenters = 'المراكز';
  static const String navBranches = 'الفروع';
  static const String navUsers = 'المستخدمون';
  static const String navReports = 'التقارير';
  static const String navSettings = 'الإعدادات';

  // ================= عناوين عامة =================
  static const String income = 'الإيرادات';
  static const String expense = 'المصروفات';
  static const String incomeShort = 'إيراد';
  static const String expenseShort = 'مصروف';
  static const String cashBalance = 'الرصيد النقدي';
  static const String openingBalance = 'الرصيد الافتتاحي';
  static const String operatingIncome = 'الإيرادات التشغيلية';
  static const String operatingExpense = 'المصروفات التشغيلية';
  static const String netCashFlow = 'صافي التدفق النقدي';
  static const String activeLoans = 'السلف القائمة';
  static const String loansRemaining = 'المبالغ المتبقية من السلف';
  static const String recentTransactions = 'آخر الحركات المالية';
  static const String monthlySummary = 'ملخص الإيرادات والمصروفات حسب الشهر';
  static const String envelopesBalances = 'أرصدة الأظرف';
  static const String auditLog = 'سجل التدقيق';
  static const String paymentMethod = 'طريقة الدفع';
  static const String forMonth = 'الشهر المالي';
  static const String attachments = 'المرفقات';
  static const String relatedEnvelope = 'الظرف المالي';
  static const String center = 'المركز';
  static const String branch = 'الفرع';
  static const String noBranch = 'بدون فرع';

  // ================= حالات =================
  static const String statusActive = 'نشط';
  static const String statusArchived = 'مؤرشف';
  static const String statusCancelled = 'ملغاة';
  static const String statusPaidOff = 'مسددة بالكامل';

  // ================= رسائل =================
  static const String offlineWarning =
      'لا يوجد اتصال بالإنترنت — قد تكون البيانات قديمة ولا يمكن تنفيذ العمليات المالية';
  static const String cachedDataWarning =
      'تُعرض بيانات مخزنة مؤقتًا وقد تكون قديمة';
  static const String noPermissionMessage =
      'لا تمتلك الصلاحية لتنفيذ هذه العملية';
  static const String serverOnlyWarning =
      'يتم التحقق من كل العمليات المالية على الخادم قبل تنفيذها';
  static const String noDataFound = 'لا توجد بيانات لعرضها';
  static const String errorGeneric = 'حدث خطأ، حاول مرة أخرى';
  static const String featureNotEditableHere =
      'هذه الحركة مرتبطة بسلفة موظف ولا يمكن إلغاؤها من هذه الشاشة';

  // ================= أدوار =================
  static const String roleAdmin = 'مدير النظام';
  static const String roleUser = 'مستخدم';

  // ================= صلاحيات =================
  static const String permissionView = 'عرض البيانات';
  static const String permissionCreate = 'إنشاء السجلات والحركات';
  static const String permissionUpdate = 'تعديل البيانات';
  static const String permissionCancel = 'إلغاء الحركات';
  static const String permissionApprove = 'اعتماد العمليات';
}
