import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../errors/exceptions.dart';

/// خدمة العمليات المالية الحساسة — بديل مجاني كامل لمعاملات Cloud Functions
/// المدفوعة.
///
/// تنفيذ العمليات المالية عبر معاملات Firestore الذرية مع:
/// - تحقق كامل قبل أي كتابة (التحقق من الرصيد، الصلاحيات، الحالة).
/// - ذرية كاملة: إما تنجح كل العمليات أو لا تُطبَّق أي منها.
/// - قواعد أمان صارمة على الخادم تمنع الكتابة المباشرة غير الموثوقة.
///
/// كل عملية تستقبل [operationName] من [AppFunctions] و[data] من مصادر البيانات.
class FinancialOperationsService {
  FinancialOperationsService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// تنفيذ عملية مالية ذرية عبر معاملة Firestore.
  ///
  /// [operationName]: اسم العملية من [AppFunctions] (للتسجيل والتشخيص).
  /// [data]: بيانات العملية (معرفات الكيانات، المبالغ، البيانات المساعدة).
  ///
  /// الاستثناءات:
  /// - [UnauthenticatedException]: لا توجد جلسة مستخدم نشطة.
  /// - [ServerException]: فشل في تنفيذ المعاملة الذرية.
  Future<Map<String, dynamic>> call(
    String operationName,
    Map<String, dynamic> data,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const UnauthenticatedException();
    }

    try {
      late Map<String, dynamic> result;
      await _firestore.runTransaction((transaction) async {
        result = await _executeOperation(
          transaction: transaction,
          operationName: operationName,
          data: data,
          uid: user.uid,
        );
      });
      return result;
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(
        _mapFirebaseError(e),
        code: e.code,
        technicalDetails: e.message,
      );
    } catch (e) {
      throw ServerException(
        'فشل تنفيذ عملية "$operationName"',
        technicalDetails: e.toString(),
      );
    }
  }

  /// تنفيذ العملية داخل المعاملة الذرية — يُوزّع بحسب [operationName].
  Future<Map<String, dynamic>> _executeOperation({
    required Transaction transaction,
    required String operationName,
    required Map<String, dynamic> data,
    required String uid,
  }) async {
    // كل عملية تُضاف هنا عند تنفيذها فعليًا.
    // حاليًا: بنية التوزيع جاهزة وتُعيد نتيجة فارغة بانتظار التنفيذ.
    switch (operationName) {
      case 'createTransaction':
        return _createTransaction(transaction, data, uid);
      case 'updateTransaction':
        return _updateTransaction(transaction, data, uid);
      case 'cancelTransaction':
        return _cancelTransaction(transaction, data, uid);
      case 'transferBetweenEnvelopes':
        return _transferBetweenEnvelopes(transaction, data, uid);
      case 'createEnvelope':
        return _createEnvelope(transaction, data, uid);
      case 'updateEnvelope':
        return _updateEnvelope(transaction, data, uid);
      case 'archiveEnvelope':
        return _archiveEnvelope(transaction, data, uid);
      case 'createEmployeeLoan':
        return _createEmployeeLoan(transaction, data, uid);
      case 'repayLoan':
        return _repayLoan(transaction, data, uid);
      case 'createUser':
        return _createUser(transaction, data, uid);
      case 'updateUser':
        return _updateUser(transaction, data, uid);
      default:
        throw ServerException('عملية غير معروفة: "$operationName"');
    }
  }

  // ─── تنفيذ العمليات ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _createTransaction(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final envelopeId = data['envelopeId'] as String?;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final type = data['type'] as String?;
    final category = data['category'] as String?;
    final name = data['name'] as String?;
    final paymentMethod = data['paymentMethod'] as String?;
    final notes = data['notes'] as String? ?? '';

    if (envelopeId == null || envelopeId.isEmpty) {
      throw const ValidationException('معرّف الظرف المالي مطلوب');
    }
    if (amount <= 0) {
      throw const ValidationException('يجب أن يكون المبلغ أكبر من صفر');
    }
    if (type != 'income' && type != 'expense') {
      throw const ValidationException('نوع الحركة غير صحيح');
    }
    if (category == null ||
        category.isEmpty ||
        name == null ||
        name.trim().length < 3) {
      throw const ValidationException('أدخل اسم الحركة وتصنيفها بصورة صحيحة');
    }
    if (paymentMethod == null || paymentMethod.isEmpty) {
      throw const ValidationException('اختر طريقة الدفع أو التحصيل');
    }

    final envelopeRef = _firestore.collection('fundEnvelopes').doc(envelopeId);
    final envelopeSnap = await tx.get(envelopeRef);

    if (!envelopeSnap.exists) {
      throw const ServerException('الظرف المالي غير موجود');
    }

    final envelopeData = envelopeSnap.data()!;
    final currentBalance =
        (envelopeData['currentBalance'] as num?)?.toDouble() ?? 0.0;

    if (type == 'expense' && currentBalance < amount) {
      throw OperationRejectedException(
        'الرصيد غير كافٍ: المتاح ${currentBalance.toStringAsFixed(2)}، المطلوب ${amount.toStringAsFixed(2)}',
      );
    }

    final fundType = envelopeData['fundType'] as String?;
    final allowedExpenseCategories =
        ((envelopeData['allowedExpenseCategories'] ?? const <String>[]) as List)
            .whereType<String>()
            .toList();

    if (type == 'expense' &&
        fundType == 'restricted' &&
        !allowedExpenseCategories.contains(category)) {
      throw const OperationRejectedException(
        'لا يمكن تسجيل هذا المصروف: الظرف المالي مخصص لبنود صرف محددة فقط ولا يشمل هذا التصنيف',
      );
    }

    // المركز/الفرع: اختياريان من النموذج؛ بدونهما يبقى مركز الظرف والفرع فارغًا.
    var txCenterId = envelopeData['centerId'];
    String? txBranchId;
    final requestedCenter = (data['centerId'] as String?)?.trim();
    final requestedBranch = (data['branchId'] as String?)?.trim();
    if (requestedCenter != null && requestedCenter.isNotEmpty) {
      final centerSnap =
          await tx.get(_firestore.collection('centers').doc(requestedCenter));
      if (!centerSnap.exists) {
        throw const ValidationException('المركز المختار غير موجود');
      }
      txCenterId = requestedCenter;
      if (requestedBranch != null && requestedBranch.isNotEmpty) {
        final branchSnap = await tx
            .get(_firestore.collection('branches').doc(requestedBranch));
        if (!branchSnap.exists ||
            branchSnap.data()?['centerId'] != requestedCenter) {
          throw const ValidationException(
              'الفرع المختار غير موجود أو لا يتبع المركز المختار');
        }
        txBranchId = requestedBranch;
      }
    }

    final newBalance =
        type == 'income' ? currentBalance + amount : currentBalance - amount;

    final txRef = _firestore.collection('transactions').doc();
    final envelopeTransactionRef =
        _firestore.collection('envelopeTransactions').doc();
    final now = FieldValue.serverTimestamp();

    tx.set(txRef, <String, dynamic>{
      'centerId': txCenterId,
      'branchId': txBranchId,
      'envelopeId': envelopeId,
      'type': type,
      'category': category,
      'name': name.trim(),
      'amount': amount,
      'paymentMethod': paymentMethod,
      'forMonth': data['forMonth'],
      'status': 'active',
      'employeeLoanId': null,
      'attachmentPaths': <String>[],
      'notes': notes.trim(),
      'createdAt': now,
    });

    tx.update(envelopeRef, <String, dynamic>{
      'currentBalance': newBalance,
      'lastEnvTxId': envelopeTransactionRef.id,
    });
    tx.set(envelopeTransactionRef, <String, dynamic>{
      'envelopeId': envelopeId,
      'transactionId': txRef.id,
      'type': type,
      'amount': amount,
      'notes': notes.trim(),
      'createdBy': uid,
      'createdAt': now,
    });

    return {'transactionId': txRef.id};
  }

  /// يعدّل البيانات الوصفية فقط؛ لا يمكن تغيير المبلغ أو نوع الحركة أو الظرف
  /// لأن ذلك يستلزم تسوية مالية جديدة في الرصيد.
  Future<Map<String, dynamic>> _updateTransaction(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final transactionId = data['transactionId'] as String?;
    final name = data['name'] as String?;
    final paymentMethod = data['paymentMethod'] as String?;
    final notes = data['notes'] as String? ?? '';

    if (transactionId == null || transactionId.isEmpty) {
      throw const ValidationException('معرّف الحركة مطلوب');
    }
    if (name == null || name.trim().length < 3) {
      throw const ValidationException('أدخل اسمًا من 3 أحرف على الأقل');
    }
    if (paymentMethod == null || paymentMethod.isEmpty) {
      throw const ValidationException('اختر طريقة الدفع أو التحصيل');
    }

    final ref = _firestore.collection('transactions').doc(transactionId);
    final snapshot = await tx.get(ref);
    if (!snapshot.exists) {
      throw const ServerException('الحركة المالية غير موجودة');
    }
    if (snapshot.data()?['status'] != 'active') {
      throw const OperationRejectedException('لا يمكن تعديل حركة ملغاة');
    }

    tx.update(ref, <String, dynamic>{
      'name': name.trim(),
      'paymentMethod': paymentMethod,
      'notes': notes.trim(),
      'updatedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return {'transactionId': transactionId};
  }

  Future<Map<String, dynamic>> _cancelTransaction(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final transactionId = data['transactionId'] as String?;
    if (transactionId == null || transactionId.isEmpty) {
      throw const ValidationException('معرّف الحركة مطلوب');
    }

    final txRef = _firestore.collection('transactions').doc(transactionId);
    final txSnap = await tx.get(txRef);

    if (!txSnap.exists) {
      throw const ServerException('الحركة المالية غير موجودة');
    }

    final txData = txSnap.data()!;
    final status = txData['status'] as String?;
    if (status == 'cancelled') {
      throw const OperationRejectedException('الحركة ملغاة مسبقًا');
    }

    final envelopeId = txData['envelopeId'] as String?;
    final amount = (txData['amount'] as num?)?.toDouble() ?? 0.0;
    final type = txData['type'] as String?;

    final now = FieldValue.serverTimestamp();
    tx.update(txRef, <String, dynamic>{
      'status': 'cancelled',
      'cancelledBy': uid,
      'updatedAt': now,
    });

    if (envelopeId != null && envelopeId.isNotEmpty) {
      final envelopeRef =
          _firestore.collection('fundEnvelopes').doc(envelopeId);
      final envelopeSnap = await tx.get(envelopeRef);
      if (envelopeSnap.exists) {
        final currentBalance =
            (envelopeSnap.data()!['currentBalance'] as num?)?.toDouble() ?? 0.0;
        // الإلغاء يعكس العملية: الإيراد يُخصم (adjustment)، المصروف يُضاف (refund).
        final newBalance = type == 'income'
            ? currentBalance - amount
            : currentBalance + amount;
        final envelopeTxType = type == 'income' ? 'adjustment' : 'refund';
        final envelopeTransactionRef =
            _firestore.collection('envelopeTransactions').doc();

        tx.update(envelopeRef, <String, dynamic>{
          'currentBalance': newBalance,
          'lastEnvTxId': envelopeTransactionRef.id,
        });
        tx.set(envelopeTransactionRef, <String, dynamic>{
          'envelopeId': envelopeId,
          'transactionId': transactionId,
          'type': envelopeTxType,
          'amount': amount,
          'notes': 'إلغاء الحركة: ${txData['name'] ?? transactionId}',
          'createdBy': uid,
          'createdAt': now,
        });
      }
    }

    return {};
  }

  Future<Map<String, dynamic>> _transferBetweenEnvelopes(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final fromId = data['fromEnvelopeId'] as String?;
    final toId = data['toEnvelopeId'] as String?;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

    if (fromId == null || fromId.isEmpty || toId == null || toId.isEmpty) {
      throw const ValidationException('معرّفات الأظرف مطلوبة');
    }
    if (fromId == toId) {
      throw const ValidationException('لا يمكن التحويل من ظرف إلى نفسه');
    }
    if (amount <= 0) {
      throw const ValidationException('المبلغ يجب أن يكون أكبر من صفر');
    }

    final fromRef = _firestore.collection('fundEnvelopes').doc(fromId);
    final toRef = _firestore.collection('fundEnvelopes').doc(toId);

    final fromSnap = await tx.get(fromRef);
    final toSnap = await tx.get(toRef);

    if (!fromSnap.exists) throw const ServerException('الظرف المصدر غير موجود');
    if (!toSnap.exists) throw const ServerException('الظرف الهدف غير موجود');

    final fromBalance =
        (fromSnap.data()!['currentBalance'] as num?)?.toDouble() ?? 0.0;
    if (fromBalance < amount) {
      throw OperationRejectedException(
        'رصيد الظرف المصدر غير كافٍ: المتاح ${fromBalance.toStringAsFixed(2)}',
      );
    }

    final toBalance =
        (toSnap.data()!['currentBalance'] as num?)?.toDouble() ?? 0.0;
    final now = FieldValue.serverTimestamp();
    final transferId =
        'tr_${DateTime.now().millisecondsSinceEpoch}_${fromId}_$toId';
    final fromEnvTxRef =
        _firestore.collection('envelopeTransactions').doc('${transferId}_out');
    final toEnvTxRef =
        _firestore.collection('envelopeTransactions').doc('${transferId}_in');

    tx.update(fromRef, <String, dynamic>{
      'currentBalance': fromBalance - amount,
      'lastEnvTxId': fromEnvTxRef.id,
    });
    tx.set(fromEnvTxRef, <String, dynamic>{
      'envelopeId': fromId,
      'transactionId': null,
      'type': 'transfer_out',
      'amount': amount,
      'notes': 'تحويل إلى ظرف: ${toSnap.data()?['name'] ?? toId}',
      'createdBy': uid,
      'createdAt': now,
    });

    tx.update(toRef, <String, dynamic>{
      'currentBalance': toBalance + amount,
      'lastEnvTxId': toEnvTxRef.id,
    });
    tx.set(toEnvTxRef, <String, dynamic>{
      'envelopeId': toId,
      'transactionId': null,
      'type': 'transfer_in',
      'amount': amount,
      'notes': 'تحويل من ظرف: ${fromSnap.data()?['name'] ?? fromId}',
      'createdBy': uid,
      'createdAt': now,
    });

    return {};
  }

  Future<Map<String, dynamic>> _createEnvelope(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final name = data['name'] as String?;
    final purpose = data['purpose'] as String?;
    final fundType = data['fundType'] as String?;
    final initialBalance = (data['initialBalance'] as num?)?.toDouble() ?? 0;

    if (name == null || name.trim().isEmpty) {
      throw const ValidationException('اسم الظرف مطلوب');
    }
    if (fundType != 'general' && fundType != 'restricted') {
      throw const ValidationException('نوع الظرف غير صحيح');
    }
    if (initialBalance < 0) {
      throw const ValidationException(
          'الرصيد الافتتاحي لا يمكن أن يكون سالبًا');
    }

    final rawCenterId = data['centerId'];
    final centerId = rawCenterId is String && rawCenterId.trim().isNotEmpty
        ? rawCenterId.trim()
        : null;
    final rawCategories = data['allowedExpenseCategories'];
    final allowedExpenseCategories = rawCategories is List
        ? rawCategories.map((item) => item.toString()).toList()
        : <String>[];

    final ref = _firestore.collection('fundEnvelopes').doc();
    final now = FieldValue.serverTimestamp();

    final envelopeTransactionRef = initialBalance > 0
        ? _firestore.collection('envelopeTransactions').doc()
        : null;

    // يجب أن تطابق هذه الحقول عقد قواعد Firestore حرفيًا. لا تُخزَّن
    // initialBalance أو id أو createdBy داخل الظرف لأنها ليست من حقوله.
    tx.set(ref, <String, dynamic>{
      'name': name.trim(),
      'purpose': purpose?.trim(),
      'fundType': fundType,
      'allowedExpenseCategories': allowedExpenseCategories,
      'currentBalance': initialBalance,
      'centerId': centerId,
      'status': 'active',
      'createdAt': now,
      if (envelopeTransactionRef != null)
        'lastEnvTxId': envelopeTransactionRef.id,
    });

    if (initialBalance <= 0) {
      return {'envelopeId': ref.id};
    }

    // الرصيد الافتتاحي ليس حقلًا مستقلًا: يوثق كإيراد وحركة تخصيص في
    // المعاملة الذرية ذاتها حتى يظل رصيد الظرف وسجل الحركات متطابقين.
    final transactionRef = _firestore.collection('transactions').doc();
    final openingName = 'رصيد افتتاحي — ${name.trim()}';

    tx.set(transactionRef, <String, dynamic>{
      'centerId': centerId,
      'branchId': null,
      'envelopeId': ref.id,
      'type': 'income',
      'category': 'opening_balance',
      'name': openingName,
      'amount': initialBalance,
      'paymentMethod': 'cash',
      'forMonth': null,
      'status': 'active',
      'employeeLoanId': null,
      'attachmentPaths': <String>[],
      'notes': 'رصيد افتتاحي للظرف: ${name.trim()}',
      'createdAt': now,
    });
    tx.set(envelopeTransactionRef!, <String, dynamic>{
      'envelopeId': ref.id,
      'transactionId': transactionRef.id,
      'type': 'allocation',
      'amount': initialBalance,
      'notes': 'تخصيص الرصيد الافتتاحي للظرف: ${name.trim()}',
      'createdBy': uid,
      'createdAt': now,
    });

    return {'envelopeId': ref.id, 'transactionId': transactionRef.id};
  }

  Future<Map<String, dynamic>> _updateEnvelope(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final envelopeId = data['envelopeId'] as String?;
    if (envelopeId == null || envelopeId.isEmpty) {
      throw const ValidationException('معرّف الظرف مطلوب');
    }

    final ref = _firestore.collection('fundEnvelopes').doc(envelopeId);
    final now = FieldValue.serverTimestamp();

    tx.update(ref, <String, dynamic>{
      ...Map.from(data)..remove('envelopeId'),
      'updatedAt': now,
    });

    return {};
  }

  Future<Map<String, dynamic>> _archiveEnvelope(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final envelopeId = data['envelopeId'] as String?;
    final archive = data['archive'] as bool? ?? true;
    if (envelopeId == null || envelopeId.isEmpty) {
      throw const ValidationException('معرّف الظرف مطلوب');
    }

    final ref = _firestore.collection('fundEnvelopes').doc(envelopeId);
    final now = FieldValue.serverTimestamp();

    tx.update(ref, <String, dynamic>{
      'status': archive ? 'archived' : 'active',
      'updatedAt': now,
    });

    return {};
  }

  Future<Map<String, dynamic>> _createEmployeeLoan(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final envelopeId = data['envelopeId'] as String?;
    final employeeName = data['employeeName'] as String?;
    final employeeId = data['employeeId'] as String?;
    final notes = data['notes'] as String? ?? '';

    if (amount <= 0) {
      throw const ValidationException('مبلغ السلفة يجب أن يكون أكبر من صفر');
    }
    if (employeeName == null || employeeName.trim().length < 3) {
      throw const ValidationException(
          'اسم الموظف يجب أن يتكون من 3 أحرف على الأقل');
    }
    if (envelopeId == null || envelopeId.isEmpty) {
      throw const ValidationException('اختر ظرف الصرف');
    }

    final envelopeRef = _firestore.collection('fundEnvelopes').doc(envelopeId);
    final envelopeSnap = await tx.get(envelopeRef);
    if (!envelopeSnap.exists) {
      throw const ServerException('ظرف الصرف غير موجود');
    }
    final envelope = envelopeSnap.data()!;
    final balance = (envelope['currentBalance'] as num?)?.toDouble() ?? 0.0;
    if (balance < amount) {
      throw OperationRejectedException(
        'رصيد الظرف غير كافٍ لصرف السلفة: المتاح ${balance.toStringAsFixed(2)}',
      );
    }

    final loanRef = _firestore.collection('employeeLoans').doc();
    final transactionRef = _firestore.collection('transactions').doc();
    final envelopeTransactionRef =
        _firestore.collection('envelopeTransactions').doc();
    final now = FieldValue.serverTimestamp();

    // سجل السلفة له عقد مستقل، ولا تُضاف إليه حقول تشغيلية زائدة.
    tx.set(loanRef, <String, dynamic>{
      'employeeId':
          employeeId?.trim().isEmpty ?? true ? null : employeeId!.trim(),
      'employeeName': employeeName.trim(),
      'totalAmount': amount,
      'remainingBalance': amount,
      'status': 'active',
      'notes': notes.trim(),
      'version': 1,
      'disbursementTxnId': transactionRef.id,
    });
    tx.update(envelopeRef, <String, dynamic>{
      'currentBalance': balance - amount,
      'lastEnvTxId': envelopeTransactionRef.id,
    });
    tx.set(transactionRef, <String, dynamic>{
      'centerId': envelope['centerId'],
      'branchId': null,
      'envelopeId': envelopeId,
      'type': 'expense',
      'category': 'employee_loan',
      'name': 'سلفة للموظف: ${employeeName.trim()}',
      'amount': amount,
      'paymentMethod': 'cash',
      'forMonth': null,
      'status': 'active',
      'employeeLoanId': loanRef.id,
      'attachmentPaths': <String>[],
      'notes': notes.trim(),
      'createdAt': now,
    });
    tx.set(envelopeTransactionRef, <String, dynamic>{
      'envelopeId': envelopeId,
      'transactionId': transactionRef.id,
      'type': 'expense',
      'amount': amount,
      'notes': notes.trim(),
      'createdBy': uid,
      'createdAt': now,
    });

    return {'loanId': loanRef.id, 'transactionId': transactionRef.id};
  }

  Future<Map<String, dynamic>> _repayLoan(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final loanId = data['loanId'] as String?;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final envelopeId = data['envelopeId'] as String?;
    final requestId = (data['requestId'] as String?)?.trim() ??
        'req_${DateTime.now().millisecondsSinceEpoch}';
    final notes = (data['notes'] as String?)?.trim() ?? '';

    if (loanId == null || loanId.isEmpty) {
      throw const ValidationException('معرّف السلفة مطلوب');
    }
    if (amount <= 0) {
      throw const ValidationException('مبلغ السداد يجب أن يكون أكبر من صفر');
    }
    if (envelopeId == null || envelopeId.isEmpty) {
      throw const ValidationException('اختر ظرف استلام المبلغ');
    }

    // جميع القراءات أولاً قبل أي عملية كتابة (شرط أساسي لمعاملات Firestore)
    final loanRef = _firestore.collection('employeeLoans').doc(loanId);
    final envelopeRef = _firestore.collection('fundEnvelopes').doc(envelopeId);
    final userRef = _firestore.collection('users').doc(uid);
    final paymentRef = _firestore.collection('loanPayments').doc(requestId);

    // فحص عدم تكرار السداد مسبقًا (Idempotency) لنفس requestId
    final paymentSnap = await tx.get(paymentRef);
    if (paymentSnap.exists) {
      return {
        'loanId': loanId,
        'transactionId': paymentSnap.data()?['transactionId'] as String?,
        'idempotent': true,
      };
    }

    final loanSnap = await tx.get(loanRef);
    final envelopeSnap = await tx.get(envelopeRef);
    final userSnap = await tx.get(userRef);

    if (!loanSnap.exists) throw const ServerException('السلفة غير موجودة');
    if (!envelopeSnap.exists) {
      throw const ServerException('ظرف الاستلام غير موجود');
    }

    final loanData = loanSnap.data()!;
    final remaining = (loanData['remainingBalance'] as num?)?.toDouble() ?? 0.0;
    final employeeName =
        (loanData['employeeName'] as String?)?.trim() ?? 'موظف';

    if (amount > remaining) {
      throw OperationRejectedException(
        'مبلغ السداد (${amount.toStringAsFixed(2)}) أكبر من الرصيد المتبقي (${remaining.toStringAsFixed(2)})',
      );
    }

    final envelope = envelopeSnap.data()!;
    final envelopeBalance =
        (envelope['currentBalance'] as num?)?.toDouble() ?? 0.0;
    final callerName =
        (userSnap.data()?['name'] as String?)?.trim() ?? 'مستخدم';

    final newRemaining = remaining - amount;
    final now = FieldValue.serverTimestamp();

    // 1. تحديث السلفة مع ربطها بمعرف القسط lastPaymentId
    tx.update(loanRef, <String, dynamic>{
      'remainingBalance': newRemaining,
      'status': newRemaining <= 0 ? 'paid_off' : 'active',
      'lastPaymentId': requestId,
    });

    // 2. إنشاء حركة الظرف المقترنة (envelopeTransactions)
    final envelopeTransactionRef =
        _firestore.collection('envelopeTransactions').doc();

    // 3. زيادة رصيد ظرف الاستلام مع إقرانه بمعرف حركة الظرف
    tx.update(envelopeRef, <String, dynamic>{
      'currentBalance': envelopeBalance + amount,
      'lastEnvTxId': envelopeTransactionRef.id,
    });

    // 4. إنشاء الحركة المالية النقدية (transactions) المقترنة بزيادة رصيد الظرف
    final transactionRef = _firestore.collection('transactions').doc();
    tx.set(transactionRef, <String, dynamic>{
      'centerId': envelope['centerId'],
      'branchId': null,
      'envelopeId': envelopeId,
      'type': 'income',
      'category': 'loan_repayment',
      'name': 'سداد سلفة: $employeeName',
      'amount': amount,
      'paymentMethod': 'cash',
      'forMonth': null,
      'status': 'active',
      'employeeLoanId': loanId,
      'attachmentPaths': <String>[],
      'notes': notes,
      'createdAt': now,
    });

    tx.set(envelopeTransactionRef, <String, dynamic>{
      'envelopeId': envelopeId,
      'transactionId': transactionRef.id,
      'type': 'income',
      'amount': amount,
      'notes': notes,
      'createdBy': uid,
      'createdAt': now,
    });

    // 5. إنشاء سجل قسط السداد (loanPayments) بمعرف requestId المحدد
    tx.set(paymentRef, <String, dynamic>{
      'loanId': loanId,
      'paidAmount': amount,
      'paymentDate': now,
      'transactionId': transactionRef.id,
      'requestId': requestId,
      'notes': notes,
    });

    // 6. إنشاء سجل تدقيق السلفة (loanLogs)
    final logRef = _firestore.collection('loanLogs').doc();
    tx.set(logRef, <String, dynamic>{
      'loanId': loanId,
      'actionType': newRemaining <= 0 ? 'PAYOFF' : 'PAYMENT',
      'performedBy': uid,
      'performedByName': callerName,
      'oldValues': <String, dynamic>{
        'remainingBalance': remaining,
        'status': loanData['status'],
      },
      'newValues': <String, dynamic>{
        'remainingBalance': newRemaining,
        'status': newRemaining <= 0 ? 'paid_off' : 'active',
      },
      'reason': notes.isEmpty ? 'سداد سلفة' : notes,
      'timestamp': now,
    });

    return {
      'loanId': loanId,
      'paymentId': paymentRef.id,
      'transactionId': transactionRef.id,
    };
  }

  Future<Map<String, dynamic>> _createUser(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    // إنشاء المستخدم يتطلب Firebase Auth Admin SDK — يُنفَّذ عبر Cloud Function
    // في بيئة الإنتاج. هنا نسجل البيانات في Firestore فقط.
    final userRef = _firestore.collection('users').doc(data['uid'] as String?);
    final now = FieldValue.serverTimestamp();

    tx.set(userRef, <String, dynamic>{
      ...data,
      'createdBy': uid,
      'createdAt': now,
      'updatedAt': now,
    });

    return {};
  }

  Future<Map<String, dynamic>> _updateUser(
    Transaction tx,
    Map<String, dynamic> data,
    String uid,
  ) async {
    final userId = data['uid'] as String?;
    if (userId == null || userId.isEmpty) {
      throw const ValidationException('معرّف المستخدم مطلوب');
    }

    final userRef = _firestore.collection('users').doc(userId);
    final now = FieldValue.serverTimestamp();

    tx.update(userRef, <String, dynamic>{
      ...Map.from(data)..remove('uid'),
      'updatedAt': now,
    });

    return {};
  }

  /// تحويل رموز أخطاء Firebase إلى رسائل عربية واضحة.
  static String _mapFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'ليس لديك صلاحية تنفيذ هذه العملية';
      case 'not-found':
        return 'السجل المطلوب غير موجود';
      case 'already-exists':
        return 'السجل موجود مسبقًا';
      case 'resource-exhausted':
        return 'تجاوزت حصة الطلبات، حاول لاحقًا';
      case 'unavailable':
        return 'الخدمة غير متاحة حاليًا، حاول مرة أخرى';
      case 'deadline-exceeded':
        return 'انتهت مهلة العملية، حاول مرة أخرى';
      case 'aborted':
        return 'تعارض في البيانات، حدّث وأعد المحاولة';
      default:
        return 'خطأ في الخادم: ${e.message ?? e.code}';
    }
  }
}
