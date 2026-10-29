import 'package:intl/intl.dart';

import 'date_time_utils.dart';
import 'money.dart';

/// تنسيق المبالغ والتواريخ والأرقام للعرض بالعربية.
/// المبالغ بأرقام غربية (أوضح في الجداول المالية) مع رمز الجنيه المصري.
abstract final class AppFormatters {
  static final NumberFormat _amountFormat = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _amountCompactFormat =
      NumberFormat('#,##0.##', 'en_US');
  static final NumberFormat _intFormat = NumberFormat('#,##0', 'en_US');

  static const String currencySymbol = 'ج.م';

  /// تحويل الأرقام العربية-الهندية إلى أرقام غربية إن وُجدت.
  static String toWesternDigits(String input) {
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    final buffer = StringBuffer();
    for (final char in input.runes) {
      final ch = String.fromCharCode(char);
      final idx = eastern.indexOf(ch);
      buffer.write(idx >= 0 ? '$idx' : ch);
    }
    return buffer.toString();
  }

  /// تنسيق مبلغ: "12,500.00 ج.م".
  static String amount(num? value) {
    if (value == null) return '${_amountFormat.format(0)} $currencySymbol';
    return '${_amountFormat.format(value)} $currencySymbol';
  }

  /// تنسيق مبلغ من كائن Money.
  static String money(Money money) => amount(money.asDouble);

  /// مبلغ بدون منازل عشرية إن كانت صفرًا: "12,500 ج.م".
  static String amountCompact(num? value) {
    if (value == null) return '${_amountCompactFormat.format(0)} $currencySymbol';
    return '${_amountCompactFormat.format(value)} $currencySymbol';
  }

  /// تنسيق رقم صحيح: "1,250".
  static String integer(num? value) => _intFormat.format(value ?? 0);

  /// تنسيق مبلغ موجب/سالب مع إشارة.
  static String amountSigned(num value, {bool showSign = false}) {
    final formatted = amount(value.abs());
    if (value < 0) return '-$formatted';
    if (showSign && value > 0) return '+$formatted';
    return formatted;
  }

  /// تنسيق تاريخ: "15 مارس 2025".
  static String date(DateTime? dateTime) {
    if (dateTime == null) return '—';
    return toWesternDigits(DateFormat('d MMMM y', 'ar').format(dateTime));
  }

  /// تنسيق تاريخ ووقت: "15 مارس 2025، 02:30 م".
  static String dateTime(DateTime? dateTime) {
    if (dateTime == null) return '—';
    return toWesternDigits(
      DateFormat('d MMMM y، hh:mm a', 'ar').format(dateTime),
    );
  }

  /// تنسيق شهر مالي "2025-03" إلى "مارس 2025".
  static String monthLabel(String? forMonth) {
    if (forMonth == null || forMonth.isEmpty) return '—';
    final parts = forMonth.split('-');
    if (parts.length != 2) return forMonth;
    final monthIndex = int.tryParse(parts[1]);
    if (monthIndex == null ||
        monthIndex < 1 ||
        monthIndex > AppDateTimeUtils.monthNames.length) {
      return forMonth;
    }
    return '${AppDateTimeUtils.monthNames[monthIndex - 1]} ${parts[0]}';
  }

  /// تنسيق النسبة المئوية.
  static String percent(double ratio) {
    final pct = (ratio * 100).clamp(0, 100);
    return '${_amountCompactFormat.format(pct)}%';
  }

  /// عرض قيمة نصية أو شرطة عند الفراغ.
  static String orDash(String? value) =>
      (value == null || value.trim().isEmpty) ? '—' : value.trim();
}
