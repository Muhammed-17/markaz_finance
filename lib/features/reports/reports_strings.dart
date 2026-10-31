/// نصوص ميزة التقارير (عربية) — ما هو مشترك يوجد في l10n/app_strings.dart.
abstract final class ReportsStrings {
  static const String reportsTitle = 'التقارير المالية';
  static const String periodLabel = 'الفترة';
  static const String periodThisMonth = 'هذا الشهر';
  static const String periodLastMonth = 'الشهر الماضي';
  static const String periodThisYear = 'هذه السنة';
  static const String periodAll = 'كل الفترات';
  static const String periodCustom = 'مخصصة';
  static const String customFromDate = 'من تاريخ';
  static const String customToDate = 'إلى تاريخ';
  static const String generateReport = 'إنشاء التقرير';
  static const String generatingReport = 'جارٍ إنشاء التقرير...';
  static const String idleMessage = 'اختر فترة وأنشئ التقرير';
  static const String noResults = 'لا توجد حركات مطابقة للفلاتر المختارة';

  static const String summarySection = 'ملخص التقرير';
  static const String loanDisbursements = 'صرف السلف (مصروف فعلي)';
  static const String loanRepayments = 'سداد السلف (إيراد فعلي)';
  static const String transfersOut = 'تحويلات صادرة بين الأظرف';
  static const String transfersIn = 'تحويلات واردة بين الأظرف';
  static const String transfersNote =
      'التحويلات بين الأظرف حركات داخلية في سجلات الأظرف فقط ولا تؤثر على الرصيد النقدي';
  static const String transactionsCountLabel = 'الحركات النشطة المشمولة';
  static const String generatedAtLabel = 'تم توليد التقرير في';

  static const String categorySection = 'التفصيل حسب التصنيف';
  static const String monthlySection = 'التفصيل حسب الشهر';
  static const String netLabel = 'الصافي';
  static const String incomeColumn = 'إيراد';
  static const String expenseColumn = 'مصروف';

  static const String pageSubtitle =
      'حلّل الإيرادات والمصروفات حسب الفترة والتصنيف';
  static const String netOperating = 'صافي التشغيل';
  static const String copySummary = 'نسخ الملخص';
  static const String summaryCopied = 'تم نسخ ملخص التقرير';
  static const String incomeTab = 'الإيرادات';
  static const String expenseTab = 'المصروفات';
  static const String totalLabel = 'الإجمالي';
  static const String noCategoryData = 'لا توجد بيانات لهذا النوع';
  static const String internalTransfers = 'تحويلات الأظرف الداخلية';
  static const String loanDisbursementsShort = 'صرف السلف';
  static const String loanRepaymentsShort = 'سداد السلف';
  static const String includedInExpenses = 'مضمّن في المصروفات';
  static const String includedInIncome = 'مضمّن في الإيرادات';
  static const String transactionsUnit = 'حركة';
}
