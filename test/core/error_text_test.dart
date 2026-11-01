import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/core/errors/error_text.dart';
import 'package:quran_centers_finance/core/errors/exceptions.dart';
import 'package:quran_centers_finance/core/errors/failures.dart';

void main() {
  group('ErrorText.of', () {
    test('أعطال الشبكة تعطي رسالة انقطاع الاتصال لا نص الاستثناء الخام', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        final text = ErrorText.of(
          ServerException('الخدمة غير متاحة حاليًا', code: code),
        );
        expect(text, ErrorText.offlineMessage);
        expect(text, isNot(contains('AppException')));
      }
    });

    test('بقية استثناءات التطبيق تعرض رسالتها فقط', () {
      expect(
        ErrorText.of(const OperationRejectedException('رصيد الظرف غير كافٍ')),
        'رصيد الظرف غير كافٍ',
      );
    });

    test('Failure وأي خطأ آخر', () {
      expect(ErrorText.of(const PermissionFailure('ممنوع')), 'ممنوع');
      expect(ErrorText.of(Exception('boom')), isNot(contains('boom')));
    });
  });
}
