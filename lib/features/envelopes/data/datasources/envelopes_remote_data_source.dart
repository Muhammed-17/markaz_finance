import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/models/envelope_model.dart';
import '../../../../core/data/models/envelope_transaction_model.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/financial_operations_service.dart';
import '../../domain/entities/envelope_form_params.dart';
import '../../domain/entities/envelope_reconciliation_entity.dart';

/// مصدر بيانات الأظرف المالية البعيد.
///
/// قواعد صارمة:
/// - القراءة فقط من Firestore؛ كل العمليات عبر [FinancialOperationsService]
///   بمعاملات Firestore الذرية مع تحقق كامل قبل الكتابة.
/// - لا يعدّل العميل الأرصدة من أي مسار خارج العملية الذرية المعتمدة.
class EnvelopesRemoteDataSource {
  EnvelopesRemoteDataSource({
    required FirebaseFirestore firestore,
    required FinancialOperationsService operations,
  })  : _firestore = firestore,
        _operations = operations;

  final FirebaseFirestore _firestore;
  final FinancialOperationsService _operations;

  CollectionReference<Map<String, dynamic>> get _envelopes =>
      _firestore.collection(AppCollections.fundEnvelopes);
  CollectionReference<Map<String, dynamic>> get _envelopeTransactions =>
      _firestore.collection(AppCollections.envelopeTransactions);
  CollectionReference<Map<String, dynamic>> get _centers =>
      _firestore.collection(AppCollections.centers);

  /// بث مباشر لكل الأظرف مرتبة بالاسم (استعلام مقروء — حقل مفرد بلا فهرس مركب).
  Stream<List<EnvelopeModel>> watchEnvelopes() {
    return _envelopes.orderBy('name').snapshots().map(
          (snapshot) =>
              snapshot.docs.map(EnvelopeModel.fromSnapshot).toList(),
        );
  }

  /// سجل حركات ظرف معين — آخر 200 حركة تنازليًا (فهرس مركب موجود).
  Future<List<EnvelopeTransactionModel>> fetchEnvelopeTransactions(
    String envelopeId,
  ) async {
    final snapshot = await _envelopeTransactions
        .where('envelopeId', isEqualTo: envelopeId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    return snapshot.docs.map(EnvelopeTransactionModel.fromSnapshot).toList();
  }

  /// مراجع المراكز للنموذج (orderBy name — استعلام مقروء).
  Future<List<CenterRef>> fetchCenters() async {
    final snapshot = await _centers.orderBy('name').get();
    return snapshot.docs
        .map((doc) => CenterRef(
              id: doc.id,
              name: (doc.data()['name'] ?? '') as String,
            ))
        .toList();
  }

  /// إنشاء ظرف — عبر العملية الذرية createEnvelope (تحقق إلزامي + ذرية).
  Future<String> createEnvelope(EnvelopeFormParams params) async {
    final result = await _operations
        .call(AppFunctions.createEnvelope, params.toCallableData());
    final id = result['envelopeId'];
    if (id is! String || id.isEmpty) {
      throw const ServerException('استجابة غير متوقعة من الخادم');
    }
    return id;
  }

  /// تعديل بيانات ظرف — عبر العملية الذرية updateEnvelope.
  Future<void> updateEnvelope(UpdateEnvelopeParams params) async {
    await _operations.call(AppFunctions.updateEnvelope, params.toCallableData());
  }

  /// أرشفة/إعادة تنشيط ظرف — عبر العملية الذرية archiveEnvelope.
  Future<void> archiveEnvelope(ArchiveEnvelopeParams params) async {
    await _operations.call(AppFunctions.archiveEnvelope, params.toCallableData());
  }

  /// تحويل بين ظرفين — عبر العملية الذرية transferBetweenEnvelopes.
  Future<void> transferBetweenEnvelopes(TransferParams params) async {
    await _operations.call(
      AppFunctions.transferBetweenEnvelopes,
      params.toCallableData(),
    );
  }

  /// فحص ومطابقة كل الأظرف ومقارنة رصيدها بمجموع حركات envelopeTransactions (الخيار ج).
  Future<EnvelopeReconciliationResult> reconcileEnvelopes() async {
    final envelopesSnap = await _envelopes.orderBy('name').get();
    final items = <EnvelopeReconciliationItem>[];

    for (final envDoc in envelopesSnap.docs) {
      final envData = envDoc.data();
      final envId = envDoc.id;
      final envName = (envData['name'] ?? '') as String;
      final currentBalance =
          ((envData['currentBalance'] ?? 0) as num).toDouble();

      final txSnap = await _envelopeTransactions
          .where('envelopeId', isEqualTo: envId)
          .get();

      double calculatedBalance = 0.0;
      for (final txDoc in txSnap.docs) {
        final d = txDoc.data();
        final type = (d['type'] ?? '') as String;
        final amount = ((d['amount'] ?? 0) as num).toDouble();
        final isAdd = type == 'income' ||
            type == 'allocation' ||
            type == 'transfer_in' ||
            type == 'refund';
        final isSub = type == 'expense' ||
            type == 'transfer_out' ||
            type == 'adjustment';
        calculatedBalance += isAdd ? amount : (isSub ? -amount : 0.0);
      }

      final diff = currentBalance - calculatedBalance;
      final isMatched = diff.abs() < 0.01;

      items.add(EnvelopeReconciliationItem(
        envelopeId: envId,
        envelopeName: envName,
        currentBalance: currentBalance,
        calculatedBalance: calculatedBalance,
        transactionCount: txSnap.docs.length,
        isMatched: isMatched,
        discrepancy: diff,
      ));
    }

    return EnvelopeReconciliationResult(
      items: items,
      reconciledAt: DateTime.now(),
    );
  }
}
