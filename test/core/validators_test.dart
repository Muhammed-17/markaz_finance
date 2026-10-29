import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/core/constants/app_constants.dart';
import 'package:quran_centers_finance/core/utils/validators.dart';

void main() {
  group('AppValidators', () {
    group('amount', () {
      test('يقبل مبالغ صحيحة', () {
        expect(AppValidators.amount('10000'), isNull);
        expect(AppValidators.amount('1250.50'), isNull);
        expect(AppValidators.amount('0.01'), isNull);
        expect(AppValidators.amount('1,250.50'), isNull); // يزيل الفواصل
      });

      test('يرفض المبالغ غير الصالحة', () {
        expect(AppValidators.amount(''), isNotNull);
        expect(AppValidators.amount('0'), isNotNull); // يجب أن يكون أكبر من صفر
        expect(AppValidators.amount('-5'), isNotNull);
        expect(AppValidators.amount('12.505'), isNotNull); // ثلاث منازل
        expect(AppValidators.amount('abc'), isNotNull);
        expect(AppValidators.amount('1e10'), isNotNull);
      });
    });

    group('forMonth', () {
      test('يقبل صيغة YYYY-MM الصحيحة', () {
        expect(AppValidators.forMonth('2025-03'), isNull);
        expect(AppValidators.forMonth('2025-12'), isNull);
        expect(AppValidators.forMonth('2025-01'), isNull);
      });

      test('يرفض الصيغ الخاطئة', () {
        expect(AppValidators.forMonth(''), isNotNull);
        expect(AppValidators.forMonth('2025-13'), isNotNull);
        expect(AppValidators.forMonth('2025-00'), isNotNull);
        expect(AppValidators.forMonth('25-03'), isNotNull);
        expect(AppValidators.forMonth('2025/03'), isNotNull);
        expect(AppValidators.forMonth('مارس'), isNotNull);
      });
    });

    group('name', () {
      test('يقبل الأسماء الصالحة ويرفض القصيرة', () {
        expect(AppValidators.name('محمد أحمد'), isNull);
        expect(AppValidators.name('محمد أحمد ' * 50), isNotNull);
        expect(AppValidators.name('مح'), isNotNull);
        expect(AppValidators.name(''), isNotNull);
        expect(AppValidators.name(null), isNotNull);
      });
    });

    group('email', () {
      test('يقبل بريدًا صحيحًا ويرفض غيره', () {
        expect(AppValidators.email('admin@center.org'), isNull);
        expect(AppValidators.email('not-an-email'), isNotNull);
        expect(AppValidators.email('a@b'), isNotNull);
        expect(AppValidators.email(''), isNotNull);
      });
    });

    group('cancelReason', () {
      test('يشترط سببًا واضحًا', () {
        expect(AppValidators.cancelReason('خطأ في التسجيل المزدوج'), isNull);
        expect(AppValidators.cancelReason('خط'), isNotNull);
        expect(AppValidators.cancelReason(''), isNotNull);
        expect(AppValidators.cancelReason('س' * 600), isNotNull);
      });
    });

    group('isValidCategory', () {
      test('يطابق التصنيف مع نوعه', () {
        expect(
          AppValidators.isValidCategory(
            AppTransactionTypes.income,
            AppIncomeCategories.donation,
          ),
          isTrue,
        );
        expect(
          AppValidators.isValidCategory(
            AppTransactionTypes.expense,
            AppIncomeCategories.donation,
          ),
          isFalse,
        );
        expect(
          AppValidators.isValidCategory(
            AppTransactionTypes.expense,
            AppExpenseCategories.salaries,
          ),
          isTrue,
        );
        expect(
          AppValidators.isValidCategory('unknown', 'salaries'),
          isFalse,
        );
      });
    });

    group('isAllowedValue', () {
      test('يتحقق من القيم المسموحة', () {
        expect(
          AppValidators.isAllowedValue('general', AppFundTypes.all),
          isTrue,
        );
        expect(
          AppValidators.isAllowedValue('unknown', AppFundTypes.all),
          isFalse,
        );
      });
    });
  });
}
