import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/core/utils/money.dart';

void main() {
  group('Money', () {
    test('يحوّل الجنيهات إلى قروش بدقة', () {
      expect(Money.fromUnits(10000).piasters, 1000000);
      expect(Money.fromUnits(1250.50).piasters, 125050);
      expect(Money.fromUnits(0.01).piasters, 1);
      expect(Money.fromUnits(99.999).piasters, 10000); // تقريب لأقرب قرش
    });

    test('يرفض القيم غير الصالحة', () {
      expect(() => Money.fromUnits(-5), throwsArgumentError);
      expect(() => Money.fromUnits(double.nan), throwsArgumentError);
      expect(() => Money.fromUnits(double.infinity), throwsArgumentError);
    });

    test('الجمع والطرح بدون أخطاء الفاصلة العائمة', () {
      // 0.1 + 0.2 في الجمع العائم لا تساوي 0.3 — Money يحل ذلك.
      final result = Money.fromUnits(0.1) + Money.fromUnits(0.2);
      expect(result.asDouble, 0.3);
      expect(result.toString(), '0.30');
    });

    test('الطرح يمنع النتيجة السالبة', () {
      expect(() => Money.fromUnits(10) - Money.fromUnits(20),
          throwsArgumentError);
      expect((Money.fromUnits(20) - Money.fromUnits(10)).asDouble, 10.0);
    });

    test('المقارنات والمساواة', () {
      expect(Money.fromUnits(5), Money.fromUnits(5.00));
      expect(Money.fromUnits(5) > Money.fromUnits(4.99), isTrue);
      expect(Money.fromUnits(5) <= Money.fromUnits(5), isTrue);
      expect(Money.zero.isZero, isTrue);
    });

    test('التحقق من دقة المنزلتين', () {
      expect(Money.hasValidPrecision(1250.50), isTrue);
      expect(Money.hasValidPrecision(1250.555), isFalse);
      expect(Money.hasValidPrecision(1250), isTrue);
    });

    test('الحد الأقصى المسموح', () {
      expect(() => Money.fromUnits(2e9), throwsArgumentError);
    });
  });
}
