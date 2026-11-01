import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/core/data/models/pending_operation_model.dart';
import 'package:quran_centers_finance/core/services/financial_operations_service.dart';
import 'package:quran_centers_finance/core/services/pending_operation_handlers.dart';

/// معالج تجريبي بنطاق إصدارات [2..3] لاختبار سياسة الإصدارات.
class _FakeHandler extends PendingOperationHandler {
  const _FakeHandler();

  @override
  String get type => 'fakeOp';
  @override
  int get currentSchemaVersion => 3;
  @override
  int get minSupportedSchemaVersion => 2;
  @override
  String? validatePayload(Map<String, dynamic> payload) =>
      payload['ok'] == true ? null : 'بيانات ناقصة';
  @override
  Future<void> execute(
    FinancialOperationsService operations,
    PendingOperationModel operation,
  ) async {}
}

PendingOperationModel _op({
  String type = 'repayLoan',
  Map<String, dynamic>? payload,
  int? schemaVersion,
}) =>
    PendingOperationModel(
      id: 'op-1',
      ownerUid: 'u1',
      type: type,
      title: 't',
      payload: payload ??
          {
            'loanId': 'loan-1',
            'amount': 100,
            'envelopeId': 'env-1',
            'requestId': 'req-12345678',
          },
      createdAt: DateTime(2026),
      schemaVersion: schemaVersion ?? PendingOperationModel.legacySchemaVersion,
    );

void main() {
  group('PendingOperationRegistry (سداد سلفة)', () {
    final registry = PendingOperationRegistry.standard();

    test('مسودة سليمة قابلة للإرسال', () {
      expect(registry.unsendableReason(_op()), isNull);
    });

    test('نوع مجهول غير مدعوم', () {
      expect(registry.unsendableReason(_op(type: 'mystery')), isNotNull);
    });

    test('إصدار أحدث من المدعوم لا يُرسل', () {
      expect(
        registry.unsendableReason(_op(schemaVersion: 99)),
        contains('أحدث'),
      );
    });

    test('بيانات ناقصة أو مبلغ غير صالح لا تُرسل', () {
      expect(
        registry.unsendableReason(_op(payload: {'loanId': 'loan-1'})),
        isNotNull,
      );
      expect(
        registry.unsendableReason(_op(payload: {
          'loanId': 'loan-1',
          'amount': 0,
          'envelopeId': 'env-1',
          'requestId': 'req-12345678',
        })),
        isNotNull,
      );
    });
  });

  group('PendingOperationRegistry (نطاق إصدارات)', () {
    final registry = PendingOperationRegistry(const [_FakeHandler()]);
    Map<String, dynamic> ok() => {'ok': true};

    test('داخل النطاق يُقبل', () {
      expect(
        registry.unsendableReason(
            _op(type: 'fakeOp', payload: ok(), schemaVersion: 2)),
        isNull,
      );
      expect(
        registry.unsendableReason(
            _op(type: 'fakeOp', payload: ok(), schemaVersion: 3)),
        isNull,
      );
    });

    test('أقدم من الحد الأدنى يُرفض بسبب نسخة قديمة', () {
      expect(
        registry.unsendableReason(
            _op(type: 'fakeOp', payload: ok(), schemaVersion: 1)),
        contains('قديمة'),
      );
    });

    test('أحدث من الحالي يُرفض', () {
      expect(
        registry.unsendableReason(
            _op(type: 'fakeOp', payload: ok(), schemaVersion: 4)),
        contains('أحدث'),
      );
    });
  });

  group('PendingOperationModel.schemaVersion', () {
    test('مسودة قديمة بلا الحقل تُقرأ كإصدار 1', () {
      final map = _op().toMap()..remove('schemaVersion');
      expect(PendingOperationModel.fromMap(map).schemaVersion, 1);
    });

    test('يُحفظ ويُقرأ كما هو، ويبقى بعد copyWith', () {
      final op = _op(schemaVersion: 5);
      expect(PendingOperationModel.fromMap(op.toMap()).schemaVersion, 5);
      expect(
        op.copyWith(status: PendingOperationStatus.failed).schemaVersion,
        5,
      );
    });
  });
}
