/// نصوص ميزة لوحة التحكم (عربية) — ما هو مشترك يوجد في l10n/app_strings.dart.
abstract final class DashboardStrings {
  static const String alertsSectionTitle = 'تنبيهات تحتاج انتباهك';
  static const String noAlerts = 'لا توجد تنبيهات';
  static const String noActiveEnvelopes = 'لا توجد أظرف نشطة حاليًا';
  static const String fundTypeGeneral = 'صندوق عام';
  static const String fundTypeRestricted = 'صندوق مخصص';
  static const String allPeriodsSubtitle = 'لكل الفترات (حركات نشطة)';
  static const String loansCountLabel = 'سلفة نشطة';
  static const String monthlySectionEmpty =
      'لا توجد حركات شهرية مسجلة لهذه السنة بعد';
  static const String refreshTooltip = 'تحديث البيانات';
  static const String viewAllTransactions = 'عرض كل الحركات';
  static const String pageSubtitle = 'نظرة عامة على الوضع المالي';
  static const String openingBalanceIncluded = 'يتضمن رصيدًا افتتاحيًا بقيمة';
  static const String envelopesTotal = 'إجمالي أرصدة الأظرف';
  static const String activeEnvelopesCount = 'ظرف نشط';
  static const String alertsTileTitle = 'التنبيهات';
  static const String alertsNeedAttention = 'تحتاج انتباهك';
  static const String shareOfTotal = 'من إجمالي الأظرف';
  static const String yearTotalIncome = 'إيراد السنة';
  static const String yearTotalExpense = 'مصروف السنة';
  static const String yearNet = 'صافي السنة';
  static const String selectedMonthNet = 'الصافي';
  static const String monthlySubtitle = 'اضغط على شهر لعرض تفاصيله';

  /// نص تنبيه ظرف مؤرشف برصيد غير صفري.
  static String archivedEnvelopeAlert(String name, String amount) =>
      'ظرف $name مؤرشف ورصيده $amount — يجب تحويل الرصيد';

  /// نص تنبيه مجمع للسلف النشطة ذات المتبقي.
  static String activeLoansSummaryAlert(int count, String amount) =>
      'يوجد $count سلفة نشطة بإجمالي متبقٍ $amount تحتاج متابعة السداد';
}
