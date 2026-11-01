import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/core/constants/app_constants.dart';
import 'package:quran_centers_finance/core/data/models/pending_operation_model.dart';
import 'package:quran_centers_finance/core/services/pending_operation_handlers.dart';

const _rid = 'req-1234-abcd';

PendingOperationModel _op(
  String type,
  Map<String, dynamic> payload, {
  int schemaVersion = 1,
}) =>
    PendingOperationModel(
      id: _rid,
      ownerUid: 'u1',
      type: type,
      title: 't',
      payload: payload,
      createdAt: DateTime(2026, 1, 1),
      schemaVersion: schemaVersion,
    );

Map<String, dynamic> _txn([Map<String, dynamic> overrides = const {}]) => {
      'envelopeId': 'env-1',
      'type': 'expense',
      'category': 'salaries',
      'name': 'صرف راتب',
      'amount': 200,
      'paymentMethod': 'cash',
      'forMonth': null,
      'notes': '',
      'requestId': _rid,
      ...overrides,
    };

Map<String, dynamic> _loan([Map<String, dynamic> overrides = const {}]) => {
      'employeeName': 'أحمد علي',
      'employeeId': null,
      'totalAmount': 300,
      'envelopeId': 'env-1',
      'notes': null,
      'requestId': _rid,
      ...overrides,
    };

Map<String, dynamic> _transfer([Map<String, dynamic> overrides = const {}]) => {
      'fromEnvelopeId': 'env-1',
      'toEnvelopeId': 'env-2',
      'amount': 150,
      'notes': null,
      'requestId': _rid,
      ...overrides,
    };

void main() {
  group('CreateTransactionHandler', () {
    const handler = CreateTransactionHandler();

    test('النوع والإصدار', () {
      expect(handler.type, AppFunctions.createTransaction);
      expect(handler.currentSchemaVersion, 1);
      expect(handler.minSupportedSchemaVersion, 1);
    });

    test('بيانات صالحة (إيراد ومصروف)', () {
      expect(handler.validatePayload(_txn()), isNull);
      expect(handler.validatePayload(_txn({'type': 'income'})), isNull);
    });

    test('كل حقل إلزامي مفقود أو غير صالح يمنع الإرسال', () {
      final bad = <Map<String, dynamic>>[
        _txn({'envelopeId': ''}),
        _txn({'envelopeId': null}),
        _txn({'type': 'transfer'}),
        _txn({'category': ''}),
        _txn({'name': 'ab'}),
        _txn({'amount': 0}),
        _txn({'amount': -5}),
        _txn({'amount': '200'}),
        _txn({'paymentMethod': ''}),
        _txn({'requestId': 'short'}),
        _txn({'requestId': null}),
      ];
      for (final payload in bad) {
        expect(handler.validatePayload(payload), isNotNull, reason: '$payload');
      }
    });
  });

  group('CreateEmployeeLoanHandler', () {
    const handler = CreateEmployeeLoanHandler();

    test('النوع والإصدار', () {
      expect(handler.type, AppFunctions.createEmployeeLoan);
      expect(handler.currentSchemaVersion, 1);
    });

    test('بيانات صالحة', () {
      expect(handler.validatePayload(_loan()), isNull);
    });

    test('حقول ناقصة أو غير صالحة تمنع الإرسال', () {
      final bad = <Map<String, dynamic>>[
        _loan({'employeeName': 'اب'}),
        _loan({'employeeName': null}),
        _loan({'totalAmount': 0}),
        _loan({'totalAmount': null}),
        _loan({'envelopeId': ''}),
        _loan({'requestId': 'x'}),
      ];
      for (final payload in bad) {
        expect(handler.validatePayload(payload), isNotNull, reason: '$payload');
      }
    });
  });

  group('TransferEnvelopesHandler', () {
    const handler = TransferEnvelopesHandler();

    test('النوع والإصدار', () {
      expect(handler.type, AppFunctions.transferBetweenEnvelopes);
      expect(handler.currentSchemaVersion, 1);
    });

    test('بيانات صالحة', () {
      expect(handler.validatePayload(_transfer()), isNull);
    });

    test('نفس الظرف أو مبلغ غير صالح أو معرّفات ناقصة تمنع الإرسال', () {
      final bad = <Map<String, dynamic>>[
        _transfer({'toEnvelopeId': 'env-1'}),
        _transfer({'fromEnvelopeId': ''}),
        _transfer({'toEnvelopeId': null}),
        _transfer({'amount': 0}),
        _transfer({'requestId': null}),
      ];
      for (final payload in bad) {
        expect(handler.validatePayload(payload), isNotNull, reason: '$payload');
      }
    });
  });

  group('PendingOperationRegistry.standard', () {
    final registry = PendingOperationRegistry.standard();

    test('فيه معالج لكل أنواع العمليات المدعومة', () {
      for (final type in [
        AppFunctions.repayLoan,
        AppFunctions.createTransaction,
        AppFunctions.createEmployeeLoan,
        AppFunctions.transferBetweenEnvelopes,
      ]) {
        expect(registry.handlerFor(type), isNotNull, reason: type);
      }
    });

    test('نوع غير مسجّل لا يُرسل', () {
      expect(registry.handlerFor(AppFunctions.createUser), isNull);
      expect(
        registry.unsendableReason(_op(AppFunctions.createUser, {})),
        isNotNull,
      );
    });

    test('المسودات الصالحة من الأنواع الجديدة قابلة للإرسال', () {
      expect(registry.unsendableReason(_op(AppFunctions.createTransaction, _txn())), isNull);
      expect(registry.unsendableReason(_op(AppFunctions.createEmployeeLoan, _loan())), isNull);
      expect(
        registry.unsendableReason(_op(AppFunctions.transferBetweenEnvelopes, _transfer())),
        isNull,
      );
    });

    test('مسودة بإصدار أحدث من المدعوم لا تُرسل وتحمل سببًا', () {
      for (final op in [
        _op(AppFunctions.createTransaction, _txn(), schemaVersion: 2),
        _op(AppFunctions.createEmployeeLoan, _loan(), schemaVersion: 2),
        _op(AppFunctions.transferBetweenEnvelopes, _transfer(), schemaVersion: 2),
      ]) {
        expect(registry.unsendableReason(op), contains('أحدث'));
      }
    });

    test('مسودة ببيانات ناقصة لا تُرسل', () {
      expect(
        registry.unsendableReason(_op(AppFunctions.createTransaction, _txn({'amount': 0}))),
        isNotNull,
      );
    });
  });
}
