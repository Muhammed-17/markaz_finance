import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_centers_finance/core/constants/app_constants.dart';
import 'package:quran_centers_finance/core/data/models/pending_operation_model.dart';
import 'package:quran_centers_finance/core/errors/exceptions.dart';
import 'package:quran_centers_finance/core/services/operation_submitter.dart';
import 'package:quran_centers_finance/core/services/pending_operation_handlers.dart';

const _rid = 'req-1234-abcd';
const _handler = TransferEnvelopesHandler();

Map<String, dynamic> _payload() => {
      'fromEnvelopeId': 'env-1',
      'toEnvelopeId': 'env-2',
      'amount': 150,
      'notes': null,
    };

class _Harness {
  _Harness({this.online = true, this.uid = 'u1', Duration? timeout}) {
    submitter = OperationSubmitter(
      isOnline: () => online,
      send: (type, payload) {
        sent.add((type, payload));
        return onSend(type, payload);
      },
      saveDraft: (op) async => drafts.add(op),
      currentUid: () => uid,
      now: () => DateTime(2026, 1, 1),
      timeout: timeout ?? const Duration(seconds: 5),
    );
  }

  bool online;
  String? uid;
  final sent = <(String, Map<String, dynamic>)>[];
  final drafts = <PendingOperationModel>[];
  Future<Object?> Function(String, Map<String, dynamic>) onSend =
      (_, __) async => <String, dynamic>{};
  late final OperationSubmitter submitter;

  Future<SubmitOutcome> submit() => submitter.submit(
        handler: _handler,
        requestId: _rid,
        payload: _payload(),
        title: 'تحويل',
      );
}

void main() {
  group('OperationSubmitter.submit', () {
    test('اتصال ونجاح: يُرسل مباشرة ولا تُحفظ مسودة', () async {
      final h = _Harness();
      expect(await h.submit(), SubmitOutcome.sent);
      expect(h.sent.length, 1);
      expect(h.sent.single.$1, AppFunctions.transferBetweenEnvelopes);
      expect(h.sent.single.$2['requestId'], _rid);
      expect(h.drafts, isEmpty);
    });

    test('بلا اتصال: تُحفظ مسودة بنفس requestId ولا يُرسل شيء', () async {
      final h = _Harness(online: false);
      expect(await h.submit(), SubmitOutcome.queued);
      expect(h.sent, isEmpty);
      final draft = h.drafts.single;
      expect(draft.id, _rid);
      expect(draft.payload['requestId'], _rid);
      expect(draft.ownerUid, 'u1');
      expect(draft.type, AppFunctions.transferBetweenEnvelopes);
      expect(draft.schemaVersion, _handler.currentSchemaVersion);
      expect(draft.status, PendingOperationStatus.pending);
    });

    test('انتهاء المهلة: تُحفظ مسودة بنفس المعرّف (قد يكون الخادم نفّذ)', () async {
      final h = _Harness(timeout: const Duration(milliseconds: 20));
      final never = Completer<Object?>();
      h.onSend = (_, __) => never.future;
      expect(await h.submit(), SubmitOutcome.queued);
      expect(h.drafts.single.id, _rid);
      expect(h.sent.single.$2['requestId'], h.drafts.single.payload['requestId']);
    });

    test('نجاح متأخر بعد المهلة لا يكسر شيئًا ويبقى المعرّف واحدًا', () async {
      final h = _Harness(timeout: const Duration(milliseconds: 20));
      final late = Completer<Object?>();
      h.onSend = (_, __) => late.future;
      expect(await h.submit(), SubmitOutcome.queued);
      late.complete(<String, dynamic>{}); // الخادم أنهى الطلب بعد المهلة
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(h.drafts.length, 1);
      expect(h.drafts.single.id, _rid);
    });

    test('أعطال عابرة (unavailable/deadline-exceeded/aborted/resource-exhausted) تُحفظ مسودة', () async {
      for (final code in [
        'unavailable',
        'deadline-exceeded',
        'aborted',
        'resource-exhausted',
      ]) {
        final h = _Harness();
        h.onSend = (_, __) async => throw ServerException('x', code: code);
        expect(await h.submit(), SubmitOutcome.queued, reason: code);
        expect(h.drafts.single.id, _rid, reason: code);
      }
    });

    test('الرفض النهائي يُعاد رميه ولا تُحفظ مسودة', () async {
      final rejections = <Object>[
        const OperationRejectedException('رصيد غير كافٍ'),
        const ValidationException('بيانات خاطئة'),
        const ServerException('x', code: 'permission-denied'),
      ];
      for (final error in rejections) {
        final h = _Harness();
        h.onSend = (_, __) async => throw error;
        await expectLater(h.submit(), throwsA(same(error)));
        expect(h.drafts, isEmpty, reason: '$error');
      }
    });

    test('بيانات غير صالحة: خطأ تحقق قبل أي إرسال أو حفظ', () async {
      final h = _Harness();
      await expectLater(
        h.submitter.submit(
          handler: _handler,
          requestId: _rid,
          payload: {..._payload(), 'toEnvelopeId': 'env-1'}, // نفس الظرف
          title: 't',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(h.sent, isEmpty);
      expect(h.drafts, isEmpty);
    });

    test('بلا جلسة: UnauthenticatedException ولا شيء يُحفظ', () async {
      final h = _Harness(uid: null);
      await expectLater(h.submit(), throwsA(isA<UnauthenticatedException>()));
      expect(h.sent, isEmpty);
      expect(h.drafts, isEmpty);
    });

    test('إعادة المحاولة بنفس requestId تُرسل المعرّف نفسه', () async {
      final h = _Harness();
      await h.submit();
      await h.submit();
      expect(h.sent.map((s) => s.$2['requestId']).toSet(), {_rid});
    });
  });

  group('OperationSubmitter.saveAsDraft', () {
    test('يحفظ مسودة دون إرسال', () async {
      final h = _Harness();
      await h.submitter.saveAsDraft(
        handler: _handler,
        requestId: _rid,
        payload: _payload(),
        title: 'تحويل',
      );
      expect(h.sent, isEmpty);
      expect(h.drafts.single.id, _rid);
      expect(h.drafts.single.payload['requestId'], _rid);
    });

    test('يرفض البيانات غير الصالحة وبلا جلسة', () async {
      final bad = _Harness();
      await expectLater(
        bad.submitter.saveAsDraft(
          handler: _handler,
          requestId: _rid,
          payload: {..._payload(), 'amount': 0},
          title: 't',
        ),
        throwsA(isA<ValidationException>()),
      );
      final anon = _Harness(uid: null);
      await expectLater(
        anon.submitter.saveAsDraft(
          handler: _handler,
          requestId: _rid,
          payload: _payload(),
          title: 't',
        ),
        throwsA(isA<UnauthenticatedException>()),
      );
      expect(bad.drafts, isEmpty);
      expect(anon.drafts, isEmpty);
    });
  });
}
