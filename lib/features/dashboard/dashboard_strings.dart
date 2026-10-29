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

  /// نص تنبيه ظرف مؤرشف برصيد غير صفري.
  static String archivedEnvelopeAlert(String name, String amount) =>
      'ظرف $name مؤرشف ورصيده $amount — يجب تحويل الرصيد';

  /// نص تنبيه مجمع للسلف النشطة ذات المتبقي.
  static String activeLoansSummaryAlert(int count, String amount) =>
      'يوجد $count سلفة نشطة بإجمالي متبقٍ $amount تحتاج متابعة السداد';
}
