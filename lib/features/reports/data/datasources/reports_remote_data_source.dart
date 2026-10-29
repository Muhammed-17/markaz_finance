import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/models/envelope_model.dart';
import '../../../../core/data/models/envelope_transaction_model.dart';
import '../../../../core/data/models/employee_loan_model.dart';
import '../../../../core/data/models/transaction_model.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../domain/entities/report_filter.dart';

/// مصدر بيانات التقارير البعيد — قراءة فقط من Firestore.
///
/// قواعد صارمة:
/// - السجل النقدي الفعلي هو مجموعة transactions (الحركات النشطة فقط).
/// - تحويلات الأظرف تُجلب من envelopeTransactions منفصلة ولا تُجمع معها أبدًا.
/// - الاستعلام الأساسي واحد متوافق مع الفهارس: مساواة status + نطاق createdAt
///   (أو فهرس status+createdAt المركب)، وبقية الفلاتر تُطبق على العميل.
class ReportsRemoteDataSource {
  ReportsRemoteDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// سقف مستندات التقرير الواحد (حماية من الاستعلامات الضخمة).
  static const int maxReportDocuments = 2000;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection(AppCollections.transactions);
  CollectionReference<Map<String, dynamic>> get _envelopeTransactions =>
      _firestore.collection(AppCollections.envelopeTransactions);
  CollectionReference<Map<String, dynamic>> get _envelopes =>
      _firestore.collection(AppCollections.fundEnvelopes);
  CollectionReference<Map<String, dynamic>> get _loans =>
      _firestore.collection(AppCollections.employeeLoans);
  CollectionReference<Map<String, dynamic>> get _centers =>
      _firestore.collection(AppCollections.centers);

  /// جلب الحركات النشطة وفق الفترة ثم تطبيق بقية الفلاتر على العميل:
  /// (type/category/centerId/envelopeId) لا يوجد فهارس مركبة تغطيها مع
  /// نطاق التاريخ، لذا يُبقى الاستعلام الأساسي بسيطًا كما هو موجّه.
  Future<List<TransactionModel>> fetchTransactions(ReportFilter filter) async {
    Query<Map<String, dynamic>> query = _transactions.where(
      'status',
      isEqualTo: AppStatuses.active,
    );

    if (filter.from != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(filter.from!),
      );
    }
    if (filter.to != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(filter.to!),
      );
    }

    // orderBy createdAt مع نطاق createdAt يعمل عبر فهرس الحقل المفرد.
    query = query.orderBy('createdAt', descending: true);

    final snapshot = await query.limit(maxReportDocuments).get();
    var models = snapshot.docs.map(TransactionModel.fromSnapshot).toList();

    if (filter.type != null) {
      models = models.where((m) => m.type == filter.type).toList();
    }
    if (filter.category != null) {
      models = models.where((m) => m.category == filter.category).toList();
    }
    if (filter.centerId != null) {
      models = models.where((m) => m.centerId == filter.centerId).toList();
    }
    if (filter.envelopeId != null) {
      models = models.where((m) => m.envelopeId == filter.envelopeId).toList();
    }

    return models;
  }

  /// تحويلات الأظرف من envelopeTransactions فقط (transfer_in/transfer_out)
  /// مع نطاق تاريخ اختياري — فهرس (type + createdAt) موجود.
  /// هذه السجلات لا تدخل في أي إجمالي نقدي للخزنة.
  Future<List<EnvelopeTransactionModel>> fetchEnvelopeTransfers({
    DateTime? from,
    DateTime? to,
  }) async {
    Query<Map<String, dynamic>> query = _envelopeTransactions.where(
      'type',
      whereIn: AppEnvelopeTransactionTypes.transferTypes,
    );

    if (from != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }
    if (to != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(to),
      );
    }

    query = query.orderBy('createdAt', descending: true);

    final snapshot = await query.limit(maxReportDocuments).get();
    return snapshot.docs.map(EnvelopeTransactionModel.fromSnapshot).toList();
  }

  /// قراءة السلف للعرض التفصيلي حسب الحالة إن طُلبت (active/paid_off).
  ///
  /// ملاحظة: بنود "صرف السلف" و"سداد السلف" في التقرير تُحسب من تصنيفات
  /// transactions (السجل النقدي الفعلي)، وهذه القراءة مخصصة لأي عرض
  /// تفصيلي لاحق لحالات السلف نفسها (فلتر loanStatus).
  Future<List<EmployeeLoanModel>> fetchLoans({String? loanStatus}) async {
    final snapshot = await _loans.get();
    var models = snapshot.docs.map(EmployeeLoanModel.fromSnapshot).toList();
    if (loanStatus != null) {
      models = models.where((m) => m.status == loanStatus).toList();
    }
    return models;
  }

  /// مراجع المراكز للقائمة المنسدلة (مرتبة بالاسم).
  Future<List<CenterRef>> fetchCenterRefs() async {
    final snapshot = await _centers.orderBy('name').get();
    return snapshot.docs
        .map((doc) => CenterRef(
              id: doc.id,
              name: (doc.data()['name'] ?? '') as String,
            ))
        .toList();
  }

  /// الأظرف (نشطة + مؤرشفة) للقائمة المنسدلة (مرتبة بالاسم).
  Future<List<EnvelopeModel>> fetchEnvelopes() async {
    final snapshot = await _envelopes.get();
    final models = snapshot.docs.map(EnvelopeModel.fromSnapshot).toList();
    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }
}
