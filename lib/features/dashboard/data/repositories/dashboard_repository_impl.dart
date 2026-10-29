import 'package:dartz/dartz.dart';

import '../../../../core/data/models/envelope_model.dart';
import '../../../../core/data/models/transaction_model.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_data_source.dart';

/// تنفيذ عقد مستودع لوحة التحكم.
///
/// الحسابات المالية كلها عبر Money بالقروش:
/// - operatingIncome = incomeTotal − openingTotal (الافتتاحي ليس إيرادًا تشغيليًا).
/// - cashBalance = openingTotal + operatingIncome − expenseTotal.
///   الخادم يضمن عدم نزول الرصيد تحت الصفر عند كل حركة؛ ولتفادي انفجار
///   Money (الذي يرفض السالب) تُحسب القيمة بالقروش الصحيحة وتُثبَّت على الصفر
///   عند وجود بيانات شاذة فقط.
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({required DashboardRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  final DashboardRemoteDataSource _remote;

  @override
  Future<Either<Failure, DashboardSummary>> getDashboardSummary({
    required int monthlyYear,
  }) async {
    try {
      final activeTransactions = await _remote.getActiveTransactions();
      final totals = _remote.calculateFinancialTotals(activeTransactions);
      final loansFuture = _remote.getLoansTotals();
      final recentFuture = _remote.getRecentTransactions(limit: 10);
      final envelopesFuture = _remote.getEnvelopesSnapshot();
      final monthlyBuckets =
          _remote.calculateMonthlyBreakdown(activeTransactions, monthlyYear);

      final results = await Future.wait([
        loansFuture,
        recentFuture,
        envelopesFuture,
      ]);

      final loans = results[0] as LoansTotalsSnapshot;
      final recent = results[1] as List<TransactionModel>;
      final envelopes = results[2] as List<EnvelopeModel>;

      // الإيرادات التشغيلية = الإيرادات النشطة − الرصيد الافتتاحي.
      final operatingPiasters =
          totals.incomeTotal.piasters - totals.openingTotal.piasters;
      final operatingIncome =
          Money(operatingPiasters < 0 ? 0 : operatingPiasters);

      final cashPiasters = totals.openingTotal.piasters +
          operatingIncome.piasters -
          totals.expenseTotal.piasters;

      final monthly = monthlyBuckets.entries
          .map((e) => DashboardMonthlyRow(
                forMonth: e.key,
                income: e.value.income,
                expense: e.value.expense,
              ))
          .toList()
        ..sort((a, b) => a.forMonth.compareTo(b.forMonth));

      return Right(DashboardSummary(
        openingBalanceTotal: totals.openingTotal,
        operatingIncomeTotal: operatingIncome,
        expenseTotal: totals.expenseTotal,
        cashBalance: Money(cashPiasters < 0 ? 0 : cashPiasters),
        activeLoansCount: loans.count,
        activeLoansTotal: loans.totalAmount,
        loansRemainingTotal: loans.remainingTotal,
        envelopes: envelopes.map((m) => m.toEntity()).toList(),
        recentTransactions: recent.map((m) => m.toEntity()).toList(),
        monthly: monthly,
        monthlyYear: monthlyYear,
      ));
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
