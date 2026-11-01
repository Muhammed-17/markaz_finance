import 'dart:async';

import '../data/models/pending_operation_model.dart';
import '../errors/exceptions.dart';
import 'pending_operation_handlers.dart';
import 'pending_operations_service.dart';

/// نتيجة محاولة تنفيذ عملية مالية.
enum SubmitOutcome {
  /// اعتمدها الخادم الآن.
  sent,

  /// حُفظت كمسودة معلّقة وتُرسل تلقائيًا (لا اتصال، أو انتهت المهلة،
  /// أو عطل عابر قد يكون الخادم نفّذ معه الطلب فعلًا).
  queued,
}

/// يرسل عملية مالية مباشرة، ويحوّلها إلى مسودة معلّقة بدل الفشل عند الأعطال
/// التي لا تعني رفض العملية: انقطاع الشبكة، انتهاء المهلة، عطل عابر.
///
/// السلامة المالية: المسودة تحمل **نفس requestId** المستخدم في المحاولة
/// المباشرة، والخادم يجعل العملية idempotent به، فإن كانت المحاولة المباشرة
/// قد نجحت وضاع ردّها لا يتكرر المبلغ عند مزامنة المسودة.
///
/// الاعتماديات تُحقن كدوال ليسهل اختباره دون Firebase.
class OperationSubmitter {
  OperationSubmitter({
    required bool Function() isOnline,
    required Future<Object?> Function(String type, Map<String, dynamic> payload)
        send,
    required Future<void> Function(PendingOperationModel operation) saveDraft,
    required String? Function() currentUid,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 20),
  })  : _isOnline = isOnline,
        _send = send,
        _saveDraft = saveDraft,
        _currentUid = currentUid,
        _now = now ?? DateTime.now;

  final bool Function() _isOnline;
  final Future<Object?> Function(String type, Map<String, dynamic> payload)
      _send;
  final Future<void> Function(PendingOperationModel operation) _saveDraft;
  final String? Function() _currentUid;
  final DateTime Function() _now;

  /// أقصى انتظار للرد قبل التحويل إلى مسودة.
  final Duration timeout;

  /// ينفّذ العملية أو يحفظها مسودة. [payload] بدون requestId — يُضاف هنا.
  ///
  /// يرمي [ValidationException] إن كانت البيانات غير صالحة للإرسال،
  /// و[UnauthenticatedException] دون جلسة، وأي رفض نهائي من الخادم كما هو
  /// (ليُعرض للمستخدم ولا يُحفظ مسودة).
  Future<SubmitOutcome> submit({
    required PendingOperationHandler handler,
    required String requestId,
    required Map<String, dynamic> payload,
    required String title,
  }) async {
    final full = _prepare(handler, requestId, payload);
    final uid = _requireUid();

    Future<SubmitOutcome> queue() async {
      await _store(handler, requestId, full, title, uid);
      return SubmitOutcome.queued;
    }

    if (!_isOnline()) return queue();

    try {
      await _send(handler.type, full).timeout(timeout);
      return SubmitOutcome.sent;
    } on TimeoutException {
      return queue();
    } catch (e) {
      if (PendingOperationsService.isTransientFailure(e)) return queue();
      rethrow;
    }
  }

  /// يحفظ العملية مسودة دون محاولة إرسال (لواجهات تُرسل عبر Bloc وتعرض الحفظ
  /// كمسودة عند انقطاع الشبكة أو عطل عابر). نفس requestId للمحاولة المباشرة.
  Future<void> saveAsDraft({
    required PendingOperationHandler handler,
    required String requestId,
    required Map<String, dynamic> payload,
    required String title,
  }) async {
    final full = _prepare(handler, requestId, payload);
    await _store(handler, requestId, full, title, _requireUid());
  }

  Map<String, dynamic> _prepare(
    PendingOperationHandler handler,
    String requestId,
    Map<String, dynamic> payload,
  ) {
    final full = <String, dynamic>{...payload, 'requestId': requestId};
    final problem = handler.validatePayload(full);
    if (problem != null) throw ValidationException(problem);
    return full;
  }

  String _requireUid() {
    final uid = _currentUid();
    if (uid == null) throw const UnauthenticatedException();
    return uid;
  }

  Future<void> _store(
    PendingOperationHandler handler,
    String requestId,
    Map<String, dynamic> full,
    String title,
    String uid,
  ) =>
      _saveDraft(PendingOperationModel(
        id: requestId, // id === requestId: معرّف واحد يمنع التكرار
        ownerUid: uid,
        type: handler.type,
        title: title,
        payload: full,
        createdAt: _now(),
        schemaVersion: handler.currentSchemaVersion,
      ));
}
