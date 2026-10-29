
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/models/envelope_model.dart';
import '../../../../core/data/models/employee_loan_model.dart';
import '../../../../core/data/models/transaction_model.dart';
import '../../../../core/utils/money.dart';

/// نتيجة إجماليات السلف النشطة (تُحسب على العميل عبر Money).
class LoansTotalsSnapshot {
  const LoansTotalsSnapshot({
    required this.count,
    required this.totalAmount,
    required this.remainingTotal,
  });

  final int count;
  final Money totalAmount;
  final Money remainingTotal;
}

/// مصدر بيانات لوحة التحكم البعيد — قراءة فقط من Firestore.
///
/// قواعد صارمة:
/// - إجماليات الخزنة من مجموعة transactions فقط (حركات نشطة).
/// - سجلات envelopeTransactions لا تُستخدم هنا إطلاقًا في أي إجمالي نقدي.
/// - ملخص لوحة التحكم لا يعتمد على فهارس مركبة، حتى لا تتعطل الصفحة أثناء
///   بناء فهرس Firestore أو عند تغيير تعريفه.
class DashboardRemoteDataSource {
  DashboardRemoteDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection(AppCollections.transactions);
  CollectionReference<Map<String, dynamic>> get _envelopes =>
      _firestore.collection(AppCollections.fundEnvelopes);
  CollectionReference<Map<String, dynamic>> get _loans =>
      _firestore.collection(AppCollections.employeeLoans);

  /// الحركات النشطة تُقرأ باستعلام بفهرس تلقائي لحقل status فقط.
  Future<List<TransactionModel>> getActiveTransactions() async {
    final snapshot = await _transactions
        .where('status', isEqualTo: AppStatuses.active)
        .get();
    return snapshot.docs.map(TransactionModel.fromSnapshot).toList();
  }

  /// تجميع محلي للإجماليات من الحركات النشطة التي جُلبت بالفعل.
  ({Money incomeTotal, Money expenseTotal, Money openingTotal})
      calculateFinancialTotals(Iterable<TransactionModel> transactions) {
    var incomeTotal = Money.zero;
    var expenseTotal = Money.zero;
    var openingTotal = Money.zero;

    for (final transaction in transactions) {
      final amount = Money.fromUnits(transaction.amount);
      if (transaction.type == AppTransactionTypes.income) {
        incomeTotal = incomeTotal + amount;
        if (transaction.category == AppIncomeCategories.openingBalance) {
          openingTotal = openingTotal + amount;
        }
      } else if (transaction.type == AppTransactionTypes.expense) {
        expenseTotal = expenseTotal + amount;
      }
    }
    return (
      incomeTotal: incomeTotal,
      expenseTotal: expenseTotal,
      openingTotal: openingTotal,
    );
  }

  /// إجماليات السلف النشطة: العدد وإجمالي المبالغ وإجمالي المتبقي.
  /// السلف صغيرة الحجم؛ تُجلب المستندات وتُجمع محليًا عبر Money.
  Future<LoansTotalsSnapshot> getLoansTotals() async {
    final snapshot =
        await _loans.where('status', isEqualTo: AppStatuses.active).get();

    var total = Money.zero;
    var remaining = Money.zero;
    for (final doc in snapshot.docs) {
      final model = EmployeeLoanModel.fromSnapshot(doc);
      total = total + Money.fromUnits(model.totalAmount);
      remaining = remaining + Money.fromUnits(model.remainingBalance);
    }

    return LoansTotalsSnapshot(
      count: snapshot.docs.length,
      totalAmount: total,
      remainingTotal: remaining,
    );
  }

  /// آخر الحركات المالية (الأحدث أولًا).
  Future<List<TransactionModel>> getRecentTransactions({
    int limit = 10,
  }) async {
    final snapshot = await _transactions
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(TransactionModel.fromSnapshot).toList();
  }

  /// لقطة الأظرف الحالية (نشطة + مؤرشفة).
  Future<List<EnvelopeModel>> getEnvelopesSnapshot() async {
    final snapshot = await _envelopes.get();
    final models = snapshot.docs.map(EnvelopeModel.fromSnapshot).toList();
    models.sort((a, b) => a.name.compareTo(b.name));
    return models;
  }

  /// التوزيع الشهري للحركات التي تم تحميلها، حسب forMonth × type.
  /// الحركات بلا شهر مالي (forMonth == null) تُستبعد من هذا الملخص.
  Map<String, ({Money income, Money expense})> calculateMonthlyBreakdown(
    Iterable<TransactionModel> transactions,
    int year,
  ) {
    final buckets = <String, ({Money income, Money expense})>{};
    for (final model in transactions) {
      final key = model.forMonth;
      if (key == null || key.length != 7 || !key.startsWith('$year-')) {
        continue;
      }

      final amount = Money.fromUnits(model.amount);
      final current = buckets[key] ?? (income: Money.zero, expense: Money.zero);
      if (model.type == AppTransactionTypes.income) {
        buckets[key] =
            (income: current.income + amount, expense: current.expense);
      } else if (model.type == AppTransactionTypes.expense) {
        buckets[key] =
            (income: current.income, expense: current.expense + amount);
      }
    }
    return buckets;
  }
}
