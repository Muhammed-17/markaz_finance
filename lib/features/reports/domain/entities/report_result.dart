import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';

/// صف تفصيل حسب التصنيف.
class ReportCategoryRow extends Equatable {
  const ReportCategoryRow({
    required this.category,
    required this.income,
    required this.expense,
  });

  final String category;

  /// إجمالي إيرادات التصنيف (صفر إن لم يوجد).
  final Money income;

  /// إجمالي مصروفات التصنيف (صفر إن لم يوجد).
  final Money expense;

  bool get isIncomeOnly => income.isPositive && !expense.isPositive;
  bool get isExpenseOnly => expense.isPositive && !income.isPositive;

  @override
  List<Object?> get props => [category, income, expense];
}

/// صف تفصيل حسب الشهر المالي.
class ReportMonthlyRow extends Equatable {
  const ReportMonthlyRow({
    required this.forMonth,
    required this.income,
    required this.expense,
  });

  /// مفتاح الشهر بصيغة YYYY-MM.
  final String forMonth;
  final Money income;
  final Money expense;

  /// صافي الشهر (قد يكون صفرًا عند التعادل أو عند بيانات شاذة؛
  /// Money لا يمثل قيمًا سالبة).
  Money get net {
    final piasters = income.piasters - expense.piasters;
    return Money(piasters < 0 ? 0 : piasters);
  }

  @override
  List<Object?> get props => [forMonth, income, expense];
}

/// نتيجة التقرير المالي — كل المبالغ كائنات Money بالقروش.
///
/// القواعد المالية المعتمدة:
/// - الإيرادات التشغيلية = إيرادات income النشطة بدون opening_balance.
/// - المصروفات التشغيلية = كل مصروفات expense النشطة (تشمل صرف السلف).
/// - صرف/سداد السلف بنود تفصيلية معروضة منفصلة (مضمنة ضمن التشغيلية).
/// - الرصيد النقدي = الافتتاحي + التشغيلي − المصروفات.
/// - تحويلات الأظرف (transfer_in/transfer_out) من سجلات envelopeTransactions
///   لا تدخل في أي إجمالي نقدي ولا تُحسب إيرادًا أو مصروفًا.
class ReportResult extends Equatable {
  const ReportResult({
    required this.openingBalanceTotal,
    required this.operatingIncomeTotal,
    required this.operatingExpenseTotal,
    required this.loanDisbursementsTotal,
    required this.loanRepaymentsTotal,
    required this.transfersInTotal,
    required this.transfersOutTotal,
    required this.cashBalance,
    required this.categoryBreakdown,
    required this.monthlyBreakdown,
    required this.transactionsCount,
    required this.generatedAt,
  });

  /// إجمالي حركات الرصيد الافتتاحي (income + category == opening_balance).
  final Money openingBalanceTotal;

  /// الإيرادات التشغيلية (بدون الافتتاحي — تشمل سداد السلف).
  final Money operatingIncomeTotal;

  /// المصروفات التشغيلية (تشمل صرف السلف).
  final Money operatingExpenseTotal;

  /// صرف السلف (expense + category == employee_loan) — بند تفصيلي.
  final Money loanDisbursementsTotal;

  /// سداد السلف (income + category == loan_repayment) — بند تفصيلي.
  final Money loanRepaymentsTotal;

  /// تحويلات واردة بين الأظرف (envelopeTransactions فقط).
  final Money transfersInTotal;

  /// تحويلات صادرة بين الأظرف (envelopeTransactions فقط).
  final Money transfersOutTotal;

  /// الرصيد النقدي الحالي للفترة وفق القاعدة:
  /// الافتتاحي + التشغيلي − المصروفات (تُثبَّت على الصفر عند بيانات شاذة).
  final Money cashBalance;

  /// تفصيل الإيرادات والمصروفات حسب التصنيف.
  final List<ReportCategoryRow> categoryBreakdown;

  /// تفصيل الإيرادات والمصروفات حسب الشهر المالي.
  final List<ReportMonthlyRow> monthlyBreakdown;

  /// عدد الحركات النشطة المشمولة بالتقرير.
  final int transactionsCount;

  /// تاريخ توليد التقرير (للعرض).
  final DateTime generatedAt;

  ReportResult copyWith({
    Money? openingBalanceTotal,
    Money? operatingIncomeTotal,
    Money? operatingExpenseTotal,
    Money? loanDisbursementsTotal,
    Money? loanRepaymentsTotal,
    Money? transfersInTotal,
    Money? transfersOutTotal,
    Money? cashBalance,
    List<ReportCategoryRow>? categoryBreakdown,
    List<ReportMonthlyRow>? monthlyBreakdown,
    int? transactionsCount,
    DateTime? generatedAt,
  }) {
    return ReportResult(
      openingBalanceTotal: openingBalanceTotal ?? this.openingBalanceTotal,
      operatingIncomeTotal: operatingIncomeTotal ?? this.operatingIncomeTotal,
      operatingExpenseTotal: operatingExpenseTotal ?? this.operatingExpenseTotal,
      loanDisbursementsTotal:
          loanDisbursementsTotal ?? this.loanDisbursementsTotal,
      loanRepaymentsTotal: loanRepaymentsTotal ?? this.loanRepaymentsTotal,
      transfersInTotal: transfersInTotal ?? this.transfersInTotal,
      transfersOutTotal: transfersOutTotal ?? this.transfersOutTotal,
      cashBalance: cashBalance ?? this.cashBalance,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
      monthlyBreakdown: monthlyBreakdown ?? this.monthlyBreakdown,
      transactionsCount: transactionsCount ?? this.transactionsCount,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  @override
  List<Object?> get props => [
        openingBalanceTotal,
        operatingIncomeTotal,
        operatingExpenseTotal,
        loanDisbursementsTotal,
        loanRepaymentsTotal,
        transfersInTotal,
        transfersOutTotal,
        cashBalance,
        categoryBreakdown,
        monthlyBreakdown,
        transactionsCount,
        generatedAt,
      ];
}
