import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/report_result.dart';
import '../../domain/repositories/reports_repository.dart';
import '../datasources/reports_remote_data_source.dart';

/// تنفيذ عقد مستودع التقارير — كل الحسابات عبر Money بالقروش.
///
/// القواعد المالية:
/// - الإيرادات التشغيلية = income النشطة بدون opening_balance.
/// - صرف السلف (employee_loan) مصروف فعلي مضمن ضمن التشغيلية،
///   وسداد السلف (loan_repayment) إيراد فعلي مضمن ضمن التشغيلية —
///   ويُعرضان منفصلين كبني تفصيليين.
/// - التحويلات بين الأظرف من envelopeTransactions وحدها ولا تدخل الرصيد.
/// - cashBalance = الافتتاحي + التشغيلي − المصروفات (تثبيت على الصفر
///   عند بيانات شاذة فقط؛ الخادم يمنع الرصيد السالب لكل حركة).
class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl({required ReportsRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  final ReportsRemoteDataSource _remote;

  @override
  Future<Either<Failure, ReportResult>> generateReport(
    ReportFilter filter,
  ) async {
    try {
      final transactions = await _remote.fetchTransactions(filter);
      final transfers = await _remote.fetchEnvelopeTransfers(
        from: filter.from,
        to: filter.to,
      );

      var openingTotal = Money.zero;
      var operatingIncomeTotal = Money.zero;
      var operatingExpenseTotal = Money.zero;
      var loanDisbursementsTotal = Money.zero;
      var loanRepaymentsTotal = Money.zero;
      var transfersInTotal = Money.zero;
      var transfersOutTotal = Money.zero;

      final categoryBuckets = <String, _CategoryBucket>{};
      final monthlyBuckets = <String, _MonthBucket>{};

      for (final t in transactions) {
        final amount = Money.fromUnits(t.amount);
        final isIncome = t.type == AppTransactionTypes.income;
        final isExpense = t.type == AppTransactionTypes.expense;

        if (isIncome) {
          if (t.category == AppIncomeCategories.openingBalance) {
            openingTotal = openingTotal + amount;
          } else {
            operatingIncomeTotal = operatingIncomeTotal + amount;
          }
          if (t.category == AppIncomeCategories.loanRepayment) {
            loanRepaymentsTotal = loanRepaymentsTotal + amount;
          }
        } else if (isExpense) {
          operatingExpenseTotal = operatingExpenseTotal + amount;
          if (t.category == AppExpenseCategories.employeeLoan) {
            loanDisbursementsTotal = loanDisbursementsTotal + amount;
          }
        }

        // تفصيل التصنيفات (التصنيف الفارغ يُعرض بمفتاح بديل حتى لا يضيع).
        final categoryKey = t.category.isEmpty ? _emptyCategoryKey : t.category;
        final categoryBucket =
            categoryBuckets.putIfAbsent(categoryKey, _CategoryBucket.new);
        if (isIncome) {
          categoryBucket.income = categoryBucket.income + amount;
        } else if (isExpense) {
          categoryBucket.expense = categoryBucket.expense + amount;
        }

        // تفصيل الأشهر: الشهر المالي أو شهر تاريخ الإنشاء.
        final monthKey = t.forMonth ?? AppDateTimeUtils.monthKey(t.createdAt);
        final monthBucket =
            monthlyBuckets.putIfAbsent(monthKey, _MonthBucket.new);
        if (isIncome) {
          monthBucket.income = monthBucket.income + amount;
        } else if (isExpense) {
          monthBucket.expense = monthBucket.expense + amount;
        }
      }

      // تحويلات الأظرف: تُجمع منفصلة ولا تُحسب إيرادًا أو مصروفًا.
      for (final transfer in transfers) {
        final amount = Money.fromUnits(transfer.amount);
        if (transfer.type == AppEnvelopeTransactionTypes.transferIn) {
          transfersInTotal = transfersInTotal + amount;
        } else if (transfer.type == AppEnvelopeTransactionTypes.transferOut) {
          transfersOutTotal = transfersOutTotal + amount;
        }
      }

      final cashPiasters = openingTotal.piasters +
          operatingIncomeTotal.piasters -
          operatingExpenseTotal.piasters;

      final categories = categoryBuckets.entries
          .map((e) => ReportCategoryRow(
                category: e.key,
                income: e.value.income,
                expense: e.value.expense,
              ))
          .toList()
        ..sort((a, b) {
          final aTotal = a.income.piasters + a.expense.piasters;
          final bTotal = b.income.piasters + b.expense.piasters;
          return bTotal.compareTo(aTotal);
        });

      final months = monthlyBuckets.entries
          .map((e) => ReportMonthlyRow(
                forMonth: e.key,
                income: e.value.income,
                expense: e.value.expense,
              ))
          .toList()
        ..sort((a, b) => a.forMonth.compareTo(b.forMonth));

      return Right(ReportResult(
        openingBalanceTotal: openingTotal,
        operatingIncomeTotal: operatingIncomeTotal,
        operatingExpenseTotal: operatingExpenseTotal,
        loanDisbursementsTotal: loanDisbursementsTotal,
        loanRepaymentsTotal: loanRepaymentsTotal,
        transfersInTotal: transfersInTotal,
        transfersOutTotal: transfersOutTotal,
        cashBalance: Money(cashPiasters < 0 ? 0 : cashPiasters),
        categoryBreakdown: categories,
        monthlyBreakdown: months,
        transactionsCount: transactions.length,
        generatedAt: DateTime.now(),
      ));
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<CenterRef>>> getCenterRefs() async {
    try {
      return Right(await _remote.fetchCenterRefs());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, List<EnvelopeEntity>>> getEnvelopes() async {
    try {
      final models = await _remote.fetchEnvelopes();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}

/// مجمع تصنيف داخلي قابل للتعديل (Money نفسها غير قابلة للتعديل).
class _CategoryBucket {
  Money income = Money.zero;
  Money expense = Money.zero;
}

/// مجمع شهر داخلي قابل للتعديل.
class _MonthBucket {
  Money income = Money.zero;
  Money expense = Money.zero;
}

/// مفتاح التصنيف الفارغ في التجميع.
const String _emptyCategoryKey = 'uncategorized';
