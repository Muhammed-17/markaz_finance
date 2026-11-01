import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/features/employee_loans/domain/entities/loan_form_params.dart';
import 'package:quran_centers_finance/features/envelopes/domain/entities/envelope_form_params.dart';

void main() {
  group('CreateLoanParams.requestId', () {
    test('لا يُرسل المفتاح إن لم يُحدَّد (سلوك قديم)', () {
      const params = CreateLoanParams(
        employeeName: 'أحمد علي',
        totalAmount: 300,
        envelopeId: 'env-1',
      );
      expect(params.toCallableData().containsKey('requestId'), isFalse);
    });

    test('يُرسل المعرّف عند تحديده ويدخل في المقارنة', () {
      const a = CreateLoanParams(
        employeeName: 'أحمد علي',
        totalAmount: 300,
        envelopeId: 'env-1',
        requestId: 'req-1234-abcd',
      );
      const b = CreateLoanParams(
        employeeName: 'أحمد علي',
        totalAmount: 300,
        envelopeId: 'env-1',
        requestId: 'req-9999-zzzz',
      );
      expect(a.toCallableData()['requestId'], 'req-1234-abcd');
      expect(a, isNot(equals(b)));
    });
  });

  group('TransferParams.requestId', () {
    test('لا يُرسل المفتاح إن لم يُحدَّد', () {
      const params = TransferParams(
        fromEnvelopeId: 'env-1',
        toEnvelopeId: 'env-2',
        amount: 100,
      );
      expect(params.toCallableData().containsKey('requestId'), isFalse);
    });

    test('يُرسل المعرّف عند تحديده', () {
      const params = TransferParams(
        fromEnvelopeId: 'env-1',
        toEnvelopeId: 'env-2',
        amount: 100,
        requestId: 'req-1234-abcd',
      );
      expect(params.toCallableData()['requestId'], 'req-1234-abcd');
    });
  });
}
