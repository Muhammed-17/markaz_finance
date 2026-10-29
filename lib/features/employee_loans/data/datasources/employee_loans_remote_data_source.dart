import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/models/audit_log_models.dart';
import '../../../../core/data/models/employee_loan_model.dart';
import '../../../../core/data/models/envelope_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/financial_operations_service.dart';
import '../../domain/entities/loan_form_params.dart';

/// مصدر بيانات سلف الموظفين البعيد.
///
/// قواعد صارمة:
/// - القراءة فقط من Firestore؛ الصرف والسداد عبر [FinancialOperationsService]
///   بمعاملات Firestore الذرية مع تحقق كامل ومنع التكرار (requestId).
/// - لا يكتب العميل remainingBalance أو currentBalance من أي مسار آخر.
class EmployeeLoansRemoteDataSource {
  EmployeeLoansRemoteDataSource({
    required FirebaseFirestore firestore,
    required FinancialOperationsService operations,
  })  : _firestore = firestore,
        _operations = operations;

  final FirebaseFirestore _firestore;
  final FinancialOperationsService _operations;

  CollectionReference<Map<String, dynamic>> get _loans =>
      _firestore.collection(AppCollections.employeeLoans);
  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection(AppCollections.loanPayments);
  CollectionReference<Map<String, dynamic>> get _logs =>
      _firestore.collection(AppCollections.loanLogs);
  CollectionReference<Map<String, dynamic>> get _envelopes =>
      _firestore.collection(AppCollections.fundEnvelopes);

  /// بث مباشر للسلف — فلتر حالة واحد (مساواة فقط، متوافق مع التصميم).
  /// الفرز على العميل بالاسم لتفادي الحاجة لفهرس مركب.
  Stream<List<EmployeeLoanModel>> watchLoans({String? status}) {
    Query<Map<String, dynamic>> query = _loans;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((snapshot) {
      final models =
          snapshot.docs.map(EmployeeLoanModel.fromSnapshot).toList();
      models.sort((a, b) => a.employeeName.compareTo(b.employeeName));
      return models;
    });
  }

  /// مدفوعات سلفة معينة — تنازليًا بتاريخ السداد (فهرس مركب موجود).
  Future<List<LoanPaymentModel>> fetchLoanPayments(String loanId) async {
    final snapshot = await _payments
        .where('loanId', isEqualTo: loanId)
        .orderBy('paymentDate', descending: true)
        .get();
    return snapshot.docs.map(LoanPaymentModel.fromSnapshot).toList();
  }

  /// سجل تدقيق سلفة معينة — آخر 100 سجل تنازليًا (فهرس مركب موجود).
  Future<List<LoanLogModel>> fetchLoanLogs(String loanId) async {
    final snapshot = await _logs
        .where('loanId', isEqualTo: loanId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();
    return snapshot.docs.map(LoanLogModel.fromSnapshot).toList();
  }

  /// الأظرف النشطة لاختيار ظرف الصرف/الاستلام في نماذج السلف
  /// (قراءة مباشرة من Firestore — الفرز على العميل بالاسم).
  Future<List<EnvelopeModel>> fetchActiveEnvelopesForLoan() async {
    final snapshot = await _envelopes
        .where('status', isEqualTo: AppStatuses.active)
        .get();
    final models = snapshot.docs.map(EnvelopeModel.fromSnapshot).toList();
    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }

  /// صرف سلفة — عبر العملية الذرية createEmployeeLoan (تحقق إلزامي:
  /// كفاية الرصيد + توافق التصنيف للظرف المخصص + ذرية العملية).
  Future<String> createLoan(CreateLoanParams params) async {
    final result = await _operations
        .call(AppFunctions.createEmployeeLoan, params.toCallableData());
    final id = result['loanId'];
    if (id is! String || id.isEmpty) {
      throw const ServerException('استجابة غير متوقعة من الخادم');
    }
    return id;
  }

  /// سداد سلفة — عبر العملية الذرية repayLoan
  /// (requestId إلزامي — منع التكرار ذريًا داخل المعاملة).
  Future<void> repayLoan(RepayLoanParams params) async {
    await _operations.call(AppFunctions.repayLoan, params.toCallableData());
  }
}
