import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart' as c;
import '../data/models/pending_operation_model.dart';
import '../network/connectivity_service.dart';
import 'financial_operations_service.dart';

/// خدمة إدارة العمليات المالية المعلقة (Offline Drafts) ومزامنتها الذرية مع Firebase.
class PendingOperationsService {
  PendingOperationsService({
    required ConnectivityService connectivityService,
    required FinancialOperationsService financialOperationsService,
  })  : _connectivity = connectivityService,
        _operations = financialOperationsService {
    _init();
  }

  final ConnectivityService _connectivity;
  final FinancialOperationsService _operations;

  StreamSubscription<bool>? _networkSub;
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

  int get pendingCount => allOperations.length;
  bool get hasPending => pendingCount > 0;

  void _init() {
    _networkSub = _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline && hasPending && !_isSyncing) {
        syncAll();
      }
    });
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(allOperations);
    }
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
  /// يُصفّي حسب [ownerUid] لمنع تنفيذ عمليات مستخدم آخر بجلسة المستخدم الحالي.
  Future<void> syncAll() async {
    if (_isSyncing || !_connectivity.isOnline) return;

    // تححق من المستخدم الحالي قبل أي عملية
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return; // لا جلسة نشطة

    _isSyncing = true;
    _notify();

    // تصفية حسب ownerUid: عمليات المستخدم الحالي فقط
    final operations =
        allOperations.where((op) => op.ownerUid == currentUid).toList();

    for (final op in operations) {
      // تحديث الحالة إلى syncing
      final syncingOp = op.copyWith(
        status: PendingOperationStatus.syncing,
        clearFailureReason: true,
      );
      await _box.put(syncingOp.id, syncingOp.toMap());
      _notify();

      try {
        await _operations.call(op.type, op.payload);
        // عند النجاح الكامل: نحذف المسودة من الصندوق
        await _box.delete(op.id);
      } catch (e) {
        // عند الفشل (مثال: تعارض رصيد، أو سُددت بالفعل): نحتفظ بها كـ failed
        String reason = e.toString();
        if (reason.startsWith('Exception: ')) {
          reason = reason.substring(11);
        }
        final failedOp = op.copyWith(
          status: PendingOperationStatus.failed,
          failureReason: reason,
        );
        await _box.put(failedOp.id, failedOp.toMap());
      }
      _notify();
    }

    _isSyncing = false;
    _notify();
  }

  void dispose() {
    _networkSub?.cancel();
    _controller.close();
  }
}
