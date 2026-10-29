import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/core/utils/date_time_utils.dart';
import 'package:quran_centers_finance/core/utils/formatters.dart';

void main() {
  group('AppFormatters', () {
    test('تنسيق المبالغ برمز الجنيه', () {
      expect(AppFormatters.amount(10000), '10,000.00 ج.م');
      expect(AppFormatters.amount(1250.5), '1,250.50 ج.م');
      expect(AppFormatters.amount(0), '0.00 ج.م');
      expect(AppFormatters.amount(null), '0.00 ج.م');
    });

    test('تنسيق المبالغ الموقعة', () {
      expect(AppFormatters.amountSigned(500), '500.00 ج.م');
      expect(AppFormatters.amountSigned(-500), '-500.00 ج.م');
      expect(
        AppFormatters.amountSigned(500, showSign: true),
        '+500.00 ج.م',
      );
    });

    test('تحويل الأرقام العربية-الهندية', () {
      expect(AppFormatters.toWesternDigits('١٢٣٤'), '1234');
      expect(AppFormatters.toWesternDigits('15 مارس ٢٠٢٥'), '15 مارس 2025');
      expect(AppFormatters.toWesternDigits('abc'), 'abc');
    });

    test('تسمية الشهر المالي', () {
      expect(AppFormatters.monthLabel('2025-03'), 'مارس 2025');
      expect(AppFormatters.monthLabel('2025-12'), 'ديسمبر 2025');
      expect(AppFormatters.monthLabel('bad'), 'bad');
      expect(AppFormatters.monthLabel(null), '—');
    });

    test('orDash', () {
      expect(AppFormatters.orDash('نص'), 'نص');
      expect(AppFormatters.orDash(''), '—');
      expect(AppFormatters.orDash(null), '—');
    });
  });

  group('AppDateTimeUtils', () {
    test('مفتاح الشهر', () {
      expect(AppDateTimeUtils.monthKey(DateTime(2025, 3, 15)), '2025-03');
      expect(AppDateTimeUtils.monthKey(DateTime(2025, 12, 1)), '2025-12');
    });

    test('تحليل مفتاح الشهر', () {
      final d = AppDateTimeUtils.parseMonthKey('2025-03');
      expect(d, DateTime(2025, 3));
      expect(AppDateTimeUtils.parseMonthKey('bad'), isNull);
      expect(AppDateTimeUtils.parseMonthKey(null), isNull);
    });

    test('نطاق الشهر', () {
      final (start, end) = AppDateTimeUtils.monthRange('2025-02');
      expect(start, DateTime(2025, 2));
      expect(end.day, 28);
      expect(end.hour, 23);
    });

    test('أسماء الأشهر', () {
      expect(AppDateTimeUtils.monthName(1), 'يناير');
      expect(AppDateTimeUtils.monthName(12), 'ديسمبر');
      expect(AppDateTimeUtils.monthName(0), '');
      expect(AppDateTimeUtils.monthName(13), '');
    });
  });
}
