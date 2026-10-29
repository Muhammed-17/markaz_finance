/// أدوات التاريخ والوقت — محسوبة بتوقيت المنطقة المحلية (إفريقيا/القاهرة).
abstract final class AppDateTimeUtils {
  static const List<String> monthNames = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  /// مفتاح الشهر المالي "YYYY-MM" من تاريخ.
  static String monthKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    return '${date.year}-$m';
  }

  /// مفتاح الشهر الحالي.
  static String get currentMonthKey => monthKey(DateTime.now());

  /// بداية اليوم.
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// نهاية اليوم.
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  /// بداية الشهر.
  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month);

  /// نهاية الشهر.
  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

  /// بداية السنة.
  static DateTime startOfYear(DateTime date) => DateTime(date.year);

  /// نهاية السنة.
  static DateTime endOfYear(DateTime date) =>
      DateTime(date.year, 12, 31, 23, 59, 59, 999);

  /// بداية الأسبوع (السبت بداية الأسبوع المصري).
  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday; // Saturday = 6
    final daysFromSaturday = (weekday + 1) % 7;
    return startOfDay(date.subtract(Duration(days: daysFromSaturday)));
  }

  /// تحويل "YYYY-MM" إلى DateTime (أول الشهر)، أو null إذا كانت غير صالحة.
  static DateTime? parseMonthKey(String? key) {
    if (key == null) return null;
    final match = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$').firstMatch(key.trim());
    if (match == null) return null;
    return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// اسم الشهر العربي من رقمه (1-12).
  static String monthName(int month) {
    if (month < 1 || month > 12) return '';
    return monthNames[month - 1];
  }

  /// عدد الأيام في شهر معين.
  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// إضافة أشهر إلى مفتاح شهر.
  static String addMonthsToKey(String key, int months) {
    final date = parseMonthKey(key);
    if (date == null) return key;
    final target = DateTime(date.year, date.month + months);
    return monthKey(target);
  }

  /// نطاق شهر مالي كامل.
  static (DateTime, DateTime) monthRange(String monthKey) {
    final start = parseMonthKey(monthKey) ?? DateTime.now();
    return (startOfMonth(start), endOfMonth(start));
  }
}
