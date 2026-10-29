import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/utils/money.dart';

/// صف شهري في ملخص الإيرادات والمصروفات (السنة المالية الحالية).
class DashboardMonthlyRow extends Equatable {
  const DashboardMonthlyRow({
    required this.forMonth,
    required this.income,
    required this.expense,
  });

  /// مفتاح الشهر المالي بصيغة YYYY-MM.
  final String forMonth;

  /// إجمالي إيرادات الشهر (حركات نشطة فقط) بالقروش.
  final Money income;

  /// إجمالي مصروفات الشهر (حركات نشطة فقط) بالقروش.
  final Money expense;

  Money get net {
    final piasters = income.piasters - expense.piasters;
    return Money(piasters < 0 ? 0 : piasters);
  }

  @override
  List<Object?> get props => [forMonth, income, expense];
}

/// الملخص المالي للوحة التحكم — كل المبالغ كائنات Money بالقروش.
///
/// القواعد المالية المعتمدة:
/// - الرصيد النقدي = الرصيد الافتتاحي + الإيرادات التشغيلية − المصروفات
///   (الحركات النشطة فقط).
/// - الرصيد الافتتاحي يُدخل في الرصيد النقدي ولا يُعد إيرادًا تشغيليًا.
/// - إجماليات الخزنة من مجموعة transactions فقط؛ سجلات الأظرف لا تُجمع معها.
class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.openingBalanceTotal,
    required this.operatingIncomeTotal,
    required this.expenseTotal,
    required this.cashBalance,
    required this.activeLoansCount,
    required this.activeLoansTotal,
    required this.loansRemainingTotal,
    required this.envelopes,
    required this.recentTransactions,
    required this.monthly,
    required this.monthlyYear,
  });

  /// إجمالي حركات الرصيد الافتتاحي (income + category == opening_balance).
  final Money openingBalanceTotal;

  /// الإيرادات التشغيلية = إجمالي الإيرادات النشطة − الرصيد الافتتاحي.
  final Money operatingIncomeTotal;

  /// إجمالي المصروفات النشطة (يشمل صرف السلف).
  final Money expenseTotal;

  /// الرصيد النقدي الحالي = الافتتاحي + التشغيلي − المصروفات.
  /// الخادم يضمن عدم نزول الرصيد تحت الصفر عند كل حركة؛
  /// وأي قيمة سالبة ناتجة عن بيانات شاذة تُعرض كصفر.
  final Money cashBalance;

  /// عدد السلف النشطة.
  final int activeLoansCount;

  /// إجمالي مبالغ السلف النشطة.
  final Money activeLoansTotal;

  /// إجمالي المتبقي من السلف النشطة.
  final Money loansRemainingTotal;

  /// لقطة الأظرف الحالية (نشطة + مؤرشفة).
  final List<EnvelopeEntity> envelopes;

  /// آخر الحركات المالية (الأحدث أولًا).
  final List<TransactionEntity> recentTransactions;

  /// التوزيع الشهري للسنة المالية [monthlyYear].
  final List<DashboardMonthlyRow> monthly;

  /// سنة الملخص الشهري.
  final int monthlyYear;

  /// الأظرف النشطة فقط (تُعرض في قسم الأرصدة).
  List<EnvelopeEntity> get activeEnvelopes =>
      envelopes.where((e) => e.isActive).toList();

  /// أظرف مؤرشفة برصيد غير صفري (تنبيهات يجب معالجتها).
  List<EnvelopeEntity> get archivedEnvelopesWithBalance => envelopes
      .where((e) => e.isArchived && Money.fromUnits(e.currentBalance).isPositive)
      .toList();

  DashboardSummary copyWith({
    Money? openingBalanceTotal,
    Money? operatingIncomeTotal,
    Money? expenseTotal,
    Money? cashBalance,
    int? activeLoansCount,
    Money? activeLoansTotal,
    Money? loansRemainingTotal,
    List<EnvelopeEntity>? envelopes,
    List<TransactionEntity>? recentTransactions,
    List<DashboardMonthlyRow>? monthly,
    int? monthlyYear,
  }) {
    return DashboardSummary(
      openingBalanceTotal: openingBalanceTotal ?? this.openingBalanceTotal,
      operatingIncomeTotal: operatingIncomeTotal ?? this.operatingIncomeTotal,
      expenseTotal: expenseTotal ?? this.expenseTotal,
      cashBalance: cashBalance ?? this.cashBalance,
      activeLoansCount: activeLoansCount ?? this.activeLoansCount,
      activeLoansTotal: activeLoansTotal ?? this.activeLoansTotal,
      loansRemainingTotal: loansRemainingTotal ?? this.loansRemainingTotal,
      envelopes: envelopes ?? this.envelopes,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      monthly: monthly ?? this.monthly,
      monthlyYear: monthlyYear ?? this.monthlyYear,
    );
  }

  @override
  List<Object?> get props => [
        openingBalanceTotal,
        operatingIncomeTotal,
        expenseTotal,
        cashBalance,
        activeLoansCount,
        activeLoansTotal,
        loansRemainingTotal,
        envelopes,
        recentTransactions,
        monthly,
        monthlyYear,
      ];
}
