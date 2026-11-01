import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart' as c;
import '../data/models/pending_operation_model.dart';
import '../errors/exceptions.dart';
import '../errors/failures.dart';
import '../network/connectivity_service.dart';
import 'financial_operations_service.dart';
import 'pending_operation_handlers.dart';

/// خدمة إدارة العمليات المالية المعلقة (Offline Drafts) ومزامنتها الذرية مع Firebase.
class PendingOperationsService {
  PendingOperationsService({
    required ConnectivityService connectivityService,
    required FinancialOperationsService financialOperationsService,
    PendingOperationRegistry? registry,
  })  : _connectivity = connectivityService,
        _operations = financialOperationsService,
        _registry = registry ?? PendingOperationRegistry.standard() {
    _init();
  }

  final ConnectivityService _connectivity;
  final FinancialOperationsService _operations;

  final PendingOperationRegistry _registry;
  StreamSubscription<bool>? _networkSub;
  StreamSubscription<User?>? _authSub;
  Timer? _retryTimer;
  int _transientAttempts = 0;

  /// استرجاع المسودات العالقة في syncing (انقطع التطبيق أثناء الإرسال) يكتمل قبل أي مزامنة.
  Future<void> _recovered = Future<void>.value();

  /// أقصى عدد لمحاولات إعادة الإرسال التلقائية بعد أعطال عابرة متتالية.
  /// بعدها تتوقف حتى حدث جديد (عودة الشبكة/تسجيل الدخول) أو ضغط يدوي.
  static const int _maxTransientAttempts = 6;
  static const Duration _baseRetryDelay = Duration(seconds: 5);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  /// أكواد أعطال Firestore العابرة: تُعاد المحاولة تلقائيًا ولا تُعلَّم failed.
  static const Set<String> _transientCodes = {
    'unavailable',
    'deadline-exceeded',
    'aborted',
    'resource-exhausted',
  };

  /// نفس التصنيف لكن على Failure القادم من الـ Bloc (مسار السداد المباشر).
  @visibleForTesting
  static bool isTransientFailureModel(Failure failure) =>
      failure is NetworkFailure ||
      (failure is ServerFailure && _transientCodes.contains(failure.code));

  /// هل الخطأ عابر (شبكة/ازدحام) أم رفض نهائي من الخادم؟
  @visibleForTesting
  static bool isTransientFailure(Object error) =>
      error is ServerException && _transientCodes.contains(error.code);
  final StreamController<List<PendingOperationModel>> _controller =
      StreamController<List<PendingOperationModel>>.broadcast();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Box<dynamic> get _box => Hive.box<dynamic>(c.AppCollections.pendingOperationsBox);

  Stream<List<PendingOperationModel>> get operationsStream => _controller.stream;

  List<PendingOperationModel> get allOperations {
    try {
      if (!Hive.isBoxOpen(c.AppCollections.pendingOperationsBox)) return [];
      final List<PendingOperationModel> list = [];
      for (final key in _box.keys) {
        final val = _box.get(key);
        if (val is Map) {
          list.add(PendingOperationModel.fromMap(Map<String, dynamic>.from(val)));
        }
      }
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    } catch (e) {
      debugPrint('PendingOperationsService.allOperations error: $e');
      return [];
    }
  }

  /// عمليات المستخدم الحالي فقط — هي ما يراه ويُزامنه هذا المستخدم.
  /// عمليات مستخدمين آخرين على نفس الجهاز تبقى محفوظة لأصحابها ولا تظهر هنا.
  List<PendingOperationModel> get ownOperations {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    return allOperations.where((op) => op.ownerUid == uid).toList();
  }

  /// كل مسودات سداد المستخدم الحالي لسلفة معينة (بما فيها المرفوضة).
  List<PendingOperationModel> repaymentsForLoan(String loanId) => ownOperations
      .where((op) =>
          op.type == c.AppFunctions.repayLoan && op.payload['loanId'] == loanId)
      .toList();

  /// المسودات القائمة فعلًا (غير المرفوضة) لسلفة معينة — لتنبيه التكرار وعرض المعلّق.
  List<PendingOperationModel> activeRepaymentsForLoan(
    String loanId, {
    String? excludeId,
  }) =>
      repaymentsForLoan(loanId)
          .where((op) =>
              op.status != PendingOperationStatus.failed && op.id != excludeId)
          .toList();

  /// مجموع مبالغ المسودات (جنيه). مبلغ مفقود أو غير رقمي يُحتسب صفرًا.
  static double sumAmount(Iterable<PendingOperationModel> ops) => ops.fold(
        0.0,
        (sum, op) => sum + ((op.payload['amount'] as num?)?.toDouble() ?? 0.0),
      );

  int get pendingCount => ownOperations.length;
  bool get hasPending => pendingCount > 0;

  /// عند الإقلاع لا يمكن أن يكون أي إرسال جارٍ، فكل syncing قديمة تُعاد pending.
  /// آمن ضد التكرار لأن requestId ثابت ويمنع الخادم إعادة تنفيذ الطلب نفسه.
  Future<void> _recoverStaleSyncing() async {
    for (final op in allOperations) {
      if (op.status == PendingOperationStatus.syncing) {
        await _box.put(
          op.id,
          op.copyWith(status: PendingOperationStatus.pending).toMap(),
        );
      }
    }
    _notify();
  }

  void _init() {
    _recovered = _recoverStaleSyncing();
    _networkSub = _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline && hasPending && !_isSyncing) {
        _transientAttempts = 0;
        syncAll();
      }
    });

    // مزامنة مسودات الجلسة السابقة عند الإقلاع/تسجيل الدخول: الاتصال قد يكون
    // متاحًا أصلًا فلا يصدر حدث تغيّر شبكة. أول بث يأتي بعد استعادة الجلسة.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _retryTimer?.cancel();
      _notify();
      if (user != null && hasPending && !_isSyncing) {
        _transientAttempts = 0;
        syncAll();
      }
    });
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(ownOperations);
    }
  }

  /// جدولة إعادة محاولة بتراجع أسّي (5ث، 15ث، 45ث ... حتى 5د).
  void _scheduleRetry() {
    _retryTimer?.cancel();
    if (_transientAttempts >= _maxTransientAttempts) return;
    final seconds = _baseRetryDelay.inSeconds * pow(3, _transientAttempts).toInt();
    final delay = Duration(
      seconds: seconds > _maxRetryDelay.inSeconds
          ? _maxRetryDelay.inSeconds
          : seconds,
    );
    _transientAttempts++;
    _retryTimer = Timer(delay, () {
      if (hasPending && !_isSyncing) syncAll();
    });
  }

  /// حفظ مسودة عملية معلقة
  Future<void> saveOperation(PendingOperationModel operation) async {
    await _box.put(operation.id, operation.toMap());
    _notify();
  }

  /// حذف مسودة
  Future<void> deleteOperation(String id) async {
    await _box.delete(id);
    _notify();
  }

  /// محاولة مزامنة كل المسودات المعلقة الخاصة بالمستخدم الحالي بالترتيب الزمني (FIFO).
  ///
  /// - يُصفّي حسب ownerUid لمنع تنفيذ عمليات مستخدم آخر بجلسة المستخدم الحالي.
  /// - الرفض النهائي من الخادم (تعارض رصيد، سُددت مسبقًا، صلاحية...) → failed.
  /// - العطل العابر (شبكة/ازدحام) → تبقى pending، يتوقف الطابور للحفاظ على
  ///   الترتيب، وتُجدوَل إعادة محاولة تلقائية بتراجع أسّي.
  /// - requestId ثابت من لحظة الحفظ، فإعادة الإرسال آمنة ضد التكرار.
  Future<void> syncAll({bool includeFailed = false}) async {
    if (_isSyncing || !_connectivity.isOnline) return;
    await _recovered;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return; // لا جلسة نشطة

    _retryTimer?.cancel();
    _isSyncing = true;
    _notify();

    var stoppedForTransient = false;
    try {
      // المحفّزات التلقائية لا تعيد إرسال المرفوض نهائيًا (قد ينجح لاحقًا بعد أن
      // يكون المستخدم عدّله وأرسل بديلًا فيتكرر)؛ المزامنة اليدوية فقط تُعيد المرفوض.
      final candidates = ownOperations
          .where((op) => includeFailed || op.status != PendingOperationStatus.failed)
          .toList();
      for (final op in candidates) {
        // نوع مجهول / إصدار غير مدعوم / بيانات ناقصة: لا تُرسل، وتبقى محفوظة مع السبب.
        final unsendable = _registry.unsendableReason(op);
        if (unsendable != null) {
          await _box.put(
            op.id,
            op
                .copyWith(
                  status: PendingOperationStatus.failed,
                  failureReason: unsendable,
                )
                .toMap(),
          );
          _notify();
          continue;
        }
        final handler = _registry.handlerFor(op.type)!;

        await _box.put(
          op.id,
          op
              .copyWith(
                status: PendingOperationStatus.syncing,
                clearFailureReason: true,
              )
              .toMap(),
        );
        _notify();

        try {
          await handler.execute(_operations, op);
          await _box.delete(op.id); // نجاح كامل: حذف المسودة
          _transientAttempts = 0;
        } catch (e) {
          if (isTransientFailure(e) || e is UnauthenticatedException) {
            // ليست رفضًا لمضمون العملية: نعيدها pending ونوقف الطابور هنا.
            await _box.put(
              op.id,
              op
                  .copyWith(
                    status: PendingOperationStatus.pending,
                    clearFailureReason: true,
                  )
                  .toMap(),
            );
            stoppedForTransient = e is! UnauthenticatedException;
            _notify();
            break;
          }
          await _box.put(
            op.id,
            op
                .copyWith(
                  status: PendingOperationStatus.failed,
                  failureReason: _readableReason(e),
                )
                .toMap(),
          );
        }
        _notify();
      }
    } finally {
      _isSyncing = false;
      _notify();
    }

    if (stoppedForTransient) _scheduleRetry();
  }

  /// سبب مقروء للمستخدم بدل toString() الخام لـ AppException.
  static String _readableReason(Object e) {
    if (e is AppException) return e.message;
    final raw = e.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }

  void dispose() {
    _networkSub?.cancel();
    _authSub?.cancel();
    _retryTimer?.cancel();
    _controller.close();
  }
}
