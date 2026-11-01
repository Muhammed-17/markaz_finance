import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/core/errors/exceptions.dart';
import 'package:quran_centers_finance/core/services/operation_ids.dart';

void main() {
  group('OperationIds.isValid', () {
    test('يقبل UUID وما يماثله (حروف وأرقام و - و _ بطول 8..64)', () {
      expect(OperationIds.isValid('3f2b8c1e-9a4d-4e7b-8c1a-0d5e6f7a8b9c'), isTrue);
      expect(OperationIds.isValid('req_1234'), isTrue);
      expect(OperationIds.isValid('A' * 64), isTrue);
    });

    test('يرفض القصير والطويل والرموز الخطرة وغير النصوص', () {
      expect(OperationIds.isValid('short'), isFalse);
      expect(OperationIds.isValid('A' * 65), isFalse);
      expect(OperationIds.isValid('has/slash-1234'), isFalse);
      expect(OperationIds.isValid('has space 1234'), isFalse);
      expect(OperationIds.isValid('..'), isFalse);
      expect(OperationIds.isValid(null), isFalse);
      expect(OperationIds.isValid(12345678), isFalse);
    });
  });

  group('OperationIds.optional', () {
    test('غير المرسل (null أو نص فارغ) يعني بلا idempotency', () {
      expect(OperationIds.optional(null), isNull);
      expect(OperationIds.optional(''), isNull);
      expect(OperationIds.optional('   '), isNull);
    });

    test('الصالح يعود كما هو', () {
      expect(OperationIds.optional('req-1234-abcd'), 'req-1234-abcd');
    });

    test('المرسل بصيغة غير صالحة خطأ تحقق (لا نكتب مستندًا بمعرّف مريب)', () {
      expect(() => OperationIds.optional('bad/id'), throwsA(isA<ValidationException>()));
      expect(() => OperationIds.optional('x'), throwsA(isA<ValidationException>()));
      expect(() => OperationIds.optional(42), throwsA(isA<ValidationException>()));
    });
  });

  group('المعرّفات المشتقة', () {
    test('حتمية: نفس requestId ينتج نفس المعرّفات دائمًا', () {
      const id = 'req-1234-abcd';
      expect(OperationIds.envelopeTransaction(id), 'req-1234-abcd_env');
      expect(OperationIds.loanDisbursement(id), 'req-1234-abcd_tx');
      expect(OperationIds.transfer(id), 'tr_req-1234-abcd');
      expect(OperationIds.transfer(id), OperationIds.transfer(id));
    });

    test('معرّفا حركة الظرف والصرف لا يتصادمان مع بعضهما', () {
      const id = 'req-1234-abcd';
      expect(
        {
          id,
          OperationIds.envelopeTransaction(id),
          OperationIds.loanDisbursement(id),
        }.length,
        3,
      );
    });
  });
}
