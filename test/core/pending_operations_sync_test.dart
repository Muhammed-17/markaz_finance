import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quran_centers_finance/core/constants/app_constants.dart' as c;
import 'package:quran_centers_finance/core/data/models/pending_operation_model.dart';
import 'package:quran_centers_finance/core/errors/exceptions.dart';
import 'package:quran_centers_finance/core/network/connectivity_service.dart';
import 'package:quran_centers_finance/core/services/financial_operations_service.dart';
import 'package:quran_centers_finance/core/services/pending_operations_service.dart';

class _FakeConnectivity extends Fake implements ConnectivityService {
  _FakeConnectivity({this.online = true});
  bool online;
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => online;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void emit(bool value) {
    online = value;
    _controller.add(value);
  }
}

class _FakeOperations extends Fake implements FinancialOperationsService {
  final calls = <(String, Map<String, dynamic>)>[];

  /// يُحدَّد لكل requestId ما يحدث عند إرساله (استثناء أو نجاح).
  final Map<String, Object> failures = {};

  @override
  Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    calls.add((functionName, data));
    final failure = failures[data['requestId']];
    if (failure != null) throw failure;
    return <String, dynamic>{};
  }
}

PendingOperationModel _transfer(
  String id, {
  String ownerUid = 'u1',
  int minute = 0,
  PendingOperationStatus status = PendingOperationStatus.pending,
  int schemaVersion = 1,
}) =>
    PendingOperationModel(
      id: id,
      ownerUid: ownerUid,
      type: c.AppFunctions.transferBetweenEnvelopes,
      title: 'تحويل $id',
      payload: {
        'fromEnvelopeId': 'env-1',
        'toEnvelopeId': 'env-2',
        'amount': 100,
        'requestId': id,
      },
      createdAt: DateTime(2026, 1, 1, 10, minute),
      status: status,
      schemaVersion: schemaVersion,
    );

void main() {
  late Directory dir;
  late Box<dynamic> box;
  late _FakeConnectivity connectivity;
  late _FakeOperations ops;
  late StreamController<String?> auth;
  String? uid;
  PendingOperationsService? service;

  Future<PendingOperationsService> build({Iterable<PendingOperationModel> seed = const []}) async {
    for (final op in seed) {
      await box.put(op.id, op.toMap());
    }
    final s = PendingOperationsService(
      connectivityService: connectivity,
      financialOperationsService: ops,
      currentUid: () => uid,
      authUidChanges: auth.stream,
    );
    service = s;
    return s;
  }

  PendingOperationModel stored(String id) =>
      PendingOperationModel.fromMap(Map<String, dynamic>.from(box.get(id) as Map));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pending_sync_test');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>(c.AppCollections.pendingOperationsBox);
    connectivity = _FakeConnectivity();
    ops = _FakeOperations();
    auth = StreamController<String?>.broadcast();
    uid = 'u1';
    service = null;
  });

  tearDown(() async {
    service?.dispose();
    await auth.close();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('النجاح يرسل بالترتيب الزمني (FIFO) ويحذف المسودات', () async {
    final s = await build(seed: [
      _transfer('req-0000-0002', minute: 2),
      _transfer('req-0000-0001', minute: 1),
    ]);
    await s.syncAll();
    expect(ops.calls.map((e) => e.$2['requestId']), ['req-0000-0001', 'req-0000-0002']);
    expect(box.isEmpty, isTrue);
  });

  test('عطل عابر: تبقى pending (لا failed) ويتوقف الطابور حفاظًا على الترتيب', () async {
    ops.failures['req-0000-0001'] = const ServerException('x', code: 'unavailable');
    final s = await build(seed: [
      _transfer('req-0000-0001', minute: 1),
      _transfer('req-0000-0002', minute: 2),
    ]);
    await s.syncAll();
    expect(ops.calls.length, 1); // الثانية لم تُرسل
    expect(stored('req-0000-0001').status, PendingOperationStatus.pending);
    expect(stored('req-0000-0001').failureReason, isNull);
    expect(stored('req-0000-0002').status, PendingOperationStatus.pending);
  });

  test('إعادة المحاولة بعد العطل العابر ترسل نفس requestId ثم تنجح', () async {
    ops.failures['req-0000-0001'] = const ServerException('x', code: 'deadline-exceeded');
    final s = await build(seed: [_transfer('req-0000-0001')]);
    await s.syncAll();
    ops.failures.clear();
    await s.syncAll();
    expect(ops.calls.map((e) => e.$2['requestId']).toSet(), {'req-0000-0001'});
    expect(ops.calls.length, 2);
    expect(box.isEmpty, isTrue);
  });

  test('رفض نهائي: failed بسبب مقروء، وتستمر باقي المسودات', () async {
    ops.failures['req-0000-0001'] = const OperationRejectedException('رصيد الظرف غير كافٍ');
    final s = await build(seed: [
      _transfer('req-0000-0001', minute: 1),
      _transfer('req-0000-0002', minute: 2),
    ]);
    await s.syncAll();
    final failed = stored('req-0000-0001');
    expect(failed.status, PendingOperationStatus.failed);
    expect(failed.failureReason, 'رصيد الظرف غير كافٍ');
    expect(box.containsKey('req-0000-0002'), isFalse); // نجحت وحُذفت
  });

  test('المرفوضة لا تُعاد تلقائيًا، وتُعاد عند المزامنة اليدوية فقط', () async {
    final s = await build(seed: [
      _transfer('req-0000-0001', status: PendingOperationStatus.failed),
    ]);
    await s.syncAll();
    expect(ops.calls, isEmpty);
    await s.syncAll(includeFailed: true);
    expect(ops.calls.length, 1);
    expect(box.isEmpty, isTrue);
  });

  test('مسودة مستخدم آخر لا تُرسل ولا تُحذف ولا تظهر', () async {
    final s = await build(seed: [
      _transfer('req-0000-0001', ownerUid: 'other'),
      _transfer('req-0000-0002', ownerUid: 'u1', minute: 1),
    ]);
    expect(s.ownOperations.map((o) => o.id), ['req-0000-0002']);
    await s.syncAll();
    expect(ops.calls.map((e) => e.$2['requestId']), ['req-0000-0002']);
    expect(stored('req-0000-0001').status, PendingOperationStatus.pending);
  });

  test('بلا جلسة أو بلا اتصال: لا إرسال', () async {
    final s = await build(seed: [_transfer('req-0000-0001')]);
    uid = null;
    await s.syncAll();
    uid = 'u1';
    connectivity.online = false;
    await s.syncAll();
    expect(ops.calls, isEmpty);
    expect(box.length, 1);
  });

  test('إصدار أحدث من المدعوم أو بيانات ناقصة → failed دون إرسال', () async {
    final broken = PendingOperationModel(
      id: 'req-0000-0002',
      ownerUid: 'u1',
      type: c.AppFunctions.transferBetweenEnvelopes,
      title: 'ناقصة',
      payload: {'requestId': 'req-0000-0002'},
      createdAt: DateTime(2026, 1, 1, 10, 2),
    );
    final s = await build(seed: [
      _transfer('req-0000-0001', minute: 1, schemaVersion: 9),
      broken,
    ]);
    await s.syncAll();
    expect(ops.calls, isEmpty);
    expect(stored('req-0000-0001').status, PendingOperationStatus.failed);
    expect(stored('req-0000-0001').failureReason, isNotEmpty);
    expect(stored('req-0000-0002').status, PendingOperationStatus.failed);
  });

  test('عند الإقلاع تُسترجع syncing العالقة إلى pending ثم تُرسل بنفس المعرّف', () async {
    final s = await build(seed: [
      _transfer('req-0000-0001', status: PendingOperationStatus.syncing),
    ]);
    await s.syncAll(); // ينتظر الاسترجاع داخليًا
    expect(ops.calls.single.$2['requestId'], 'req-0000-0001');
    expect(box.isEmpty, isTrue);
  });

  test('عودة الشبكة تُطلق المزامنة تلقائيًا', () async {
    connectivity.online = false;
    await build(seed: [_transfer('req-0000-0001')]);
    connectivity.emit(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ops.calls.length, 1);
    expect(box.isEmpty, isTrue);
  });

  test('تسجيل الدخول يُطلق مزامنة مسودات الجلسة السابقة', () async {
    await build(seed: [_transfer('req-0000-0001')]);
    auth.add('u1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(ops.calls.length, 1);
  });

  group('retryDelay (تراجع أسّي)', () {
    test('5ث، 15ث، 45ث، 135ث، ثم سقف 5 دقائق', () {
      final seconds = [for (var i = 0; i < 6; i++) PendingOperationsService.retryDelay(i).inSeconds];
      expect(seconds, [5, 15, 45, 135, 300, 300]);
    });
  });
}
