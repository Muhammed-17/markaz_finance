import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../transactions/presentation/widgets/month_field.dart'
    show categoryLabel;
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/report_result.dart';
import '../../domain/usecases/reports_usecases.dart';
import '../../reports_strings.dart';
import '../bloc/reports_bloc.dart';
import '../widgets/report_filters_bar.dart';

/// صفحة التقارير المالية: شريط فلاتر + ملخص تنفيذي + تفصيل بالتصنيف والشهر.
/// تُعرض داخل الهيكل العام AppShell.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final LoadReportCenterRefs _loadCenters;
  late final LoadReportEnvelopes _loadEnvelopes;

  List<CenterRef> _centers = const [];
  List<EnvelopeEntity> _envelopes = const [];

  ReportPeriod _selectedPeriod = ReportPeriod.thisMonth;
  DateTime? _customFrom;
  DateTime? _customTo;
  ReportFilter _filter = const ReportFilter();

  @override
  void initState() {
    super.initState();
    _loadCenters = sl<LoadReportCenterRefs>();
    _loadEnvelopes = sl<LoadReportEnvelopes>();
    _loadReferences();
    // تطبيق الفترة الافتراضية مباشرة دون setState أثناء التهيئة.
    final defaultBounds = ReportPeriodBounds.resolve(ReportPeriod.thisMonth);
    _selectedPeriod = ReportPeriod.thisMonth;
    _filter = ReportFilter(from: defaultBounds.$1, to: defaultBounds.$2);
  }

  Future<void> _loadReferences() async {
    final centersResult = await _loadCenters();
    final envelopesResult = await _loadEnvelopes();
    if (!mounted) return;
    setState(() {
      _centers = centersResult.fold((_) => _centers, (list) => list);
      _envelopes = envelopesResult.fold((_) => _envelopes, (list) => list);
    });
  }

  void _applyPeriod(ReportPeriod period) {
    final bounds = ReportPeriodBounds.resolve(
      period,
      customFrom: _customFrom,
      customTo: _customTo,
    );
    setState(() {
      _selectedPeriod = period;
      _filter = ReportFilter(
        from: bounds.$1,
        to: bounds.$2,
        centerId: _filter.centerId,
        type: _filter.type,
        category: _filter.category,
        envelopeId: _filter.envelopeId,
        loanStatus: _filter.loanStatus,
      );
    });
  }

  void _onCustomDatesPicked(DateTime? from, DateTime? to) {
    setState(() {
      _customFrom = from;
      _customTo = to == null ? null : AppDateTimeUtils.endOfDay(to);
      _filter = ReportFilter(
        from: _customFrom,
        to: _customTo,
        centerId: _filter.centerId,
        type: _filter.type,
        category: _filter.category,
        envelopeId: _filter.envelopeId,
        loanStatus: _filter.loanStatus,
      );
    });
  }

  void _onFilterChanged(ReportFilter filter) {
    setState(() => _filter = filter);
  }

  void _generate() {
    context.read<ReportsBloc>().add(GenerateReportRequested(_filter));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(AppStrings.navReports,
                  style: AppTypography.headlineMedium),
              const SizedBox(height: AppDimensions.itemSpacing),
              ReportFiltersBar(
                filter: _filter,
                centers: _centers,
                envelopes: _envelopes,
                selectedPeriod: _selectedPeriod,
                isGenerating: state.isGenerating,
                onPeriodSelected: _applyPeriod,
                onCustomDatesPicked: _onCustomDatesPicked,
                onFilterChanged: _onFilterChanged,
                onGenerate: _generate,
              ),
              const SizedBox(height: AppDimensions.sectionSpacing),
              _ResultsSection(state: state),
              const SizedBox(height: AppDimensions.sectionSpacing),
            ],
          ),
        );
      },
    );
  }
}

/// قسم النتائج: idle / generating / failure / success.
class _ResultsSection extends StatelessWidget {
  const _ResultsSection({required this.state});

  final ReportsState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ReportsStatus.idle:
        return const AppEmptyView(
          message: ReportsStrings.idleMessage,
          icon: Icons.query_stats_rounded,
        );
      case ReportsStatus.generating:
        return const AppLoadingView(message: ReportsStrings.generatingReport);
      case ReportsStatus.failure:
        return AppErrorView(
          message: state.failure?.message ?? AppStrings.errorGeneric,
          onRetry: () => context
              .read<ReportsBloc>()
              .add(GenerateReportRequested(state.filter)),
        );
      case ReportsStatus.success:
        final result = state.result;
        if (result == null) {
          return const AppEmptyView(message: AppStrings.noDataFound);
        }
        if (result.transactionsCount == 0 &&
            !result.transfersInTotal.isPositive &&
            !result.transfersOutTotal.isPositive) {
          return const AppEmptyView(
            message: ReportsStrings.noResults,
            icon: Icons.receipt_long_outlined,
          );
        }
        return _ReportBody(result: result);
    }
  }
}

/// جسم التقرير: الملخص + التفاصيل.
class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.result});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(result: result),
        const SizedBox(height: AppDimensions.sectionSpacing),
        _CategoryBreakdownCard(rows: result.categoryBreakdown),
        const SizedBox(height: AppDimensions.sectionSpacing),
        _MonthlyBreakdownCard(rows: result.monthlyBreakdown),
      ],
    );
  }
}

/// جدول الملخص التنفيذي.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(ReportsStrings.summarySection,
              style: AppTypography.headlineSmall),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            '${ReportsStrings.generatedAtLabel} '
            '${AppFormatters.dateTime(result.generatedAt)} • '
            '${ReportsStrings.transactionsCountLabel}: '
            '${AppFormatters.integer(result.transactionsCount)}',
            style: AppTypography.labelSmall,
          ),
          const SizedBox(height: AppDimensions.spacing12),
          _SummaryRow(
            label: AppStrings.openingBalance,
            value: AppFormatters.money(result.openingBalanceTotal),
          ),
          _SummaryRow(
            label: AppStrings.operatingIncome,
            value: AppFormatters.money(result.operatingIncomeTotal),
            valueColor: AppColors.income,
          ),
          _SummaryRow(
            label: AppStrings.operatingExpense,
            value: AppFormatters.money(result.operatingExpenseTotal),
            valueColor: AppColors.expense,
          ),
          _SummaryRow(
            label: ReportsStrings.loanDisbursements,
            value: AppFormatters.money(result.loanDisbursementsTotal),
            valueColor: AppColors.expense,
            isMuted: true,
          ),
          _SummaryRow(
            label: ReportsStrings.loanRepayments,
            value: AppFormatters.money(result.loanRepaymentsTotal),
            valueColor: AppColors.income,
            isMuted: true,
          ),
          _SummaryRow(
            label: ReportsStrings.transfersOut,
            value: AppFormatters.money(result.transfersOutTotal),
            isMuted: true,
          ),
          _SummaryRow(
            label: ReportsStrings.transfersIn,
            value: AppFormatters.money(result.transfersInTotal),
            isMuted: true,
          ),
          const SizedBox(height: AppDimensions.spacing8),
          _CashBalanceRow(value: AppFormatters.money(result.cashBalance)),
          const SizedBox(height: AppDimensions.spacing8),
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: AppDimensions.iconSmall + 2,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(
                  ReportsStrings.transfersNote,
                  style: AppTypography.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isMuted = false,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// بند تفصيلي معروض منفصلًا (مضمن ضمن الإجماليات التشغيلية).
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              isMuted ? '$label *' : label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

/// صف الرصيد النقدي المميز.
class _CashBalanceRow extends StatelessWidget {
  const _CashBalanceRow({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppDimensions.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              AppStrings.cashBalance,
              style: AppTypography.titleMedium,
            ),
          ),
          Text(
            value,
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// تفصيل حسب التصنيف.
class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.rows});

  final List<ReportCategoryRow> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(ReportsStrings.categorySection,
              style: AppTypography.headlineSmall),
          const SizedBox(height: AppDimensions.spacing12),
          if (rows.isEmpty)
            const AppEmptyView(
              message: AppStrings.noDataFound,
              isCompact: true,
            )
          else ...[
            const _BreakdownHeader(
              label: AppStrings.category,
              showNet: false,
            ),
            const SizedBox(height: AppDimensions.spacing4),
            ...rows.map(
              (row) => _CategoryRowTile(
                label: categoryLabel(row.category),
                income: row.income,
                expense: row.expense,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// تفصيل حسب الشهر.
class _MonthlyBreakdownCard extends StatelessWidget {
  const _MonthlyBreakdownCard({required this.rows});

  final List<ReportMonthlyRow> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(ReportsStrings.monthlySection,
              style: AppTypography.headlineSmall),
          const SizedBox(height: AppDimensions.spacing12),
          if (rows.isEmpty)
            const AppEmptyView(
              message: AppStrings.noDataFound,
              isCompact: true,
            )
          else ...[
            const _BreakdownHeader(
              label: AppStrings.forMonth,
              showNet: true,
            ),
            const SizedBox(height: AppDimensions.spacing4),
            ...rows.map(
              (row) => _MonthlyRowTile(
                label: AppFormatters.monthLabel(row.forMonth),
                income: row.income,
                expense: row.expense,
                net: row.net,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ترويسة جداول التفصيل.
class _BreakdownHeader extends StatelessWidget {
  const _BreakdownHeader({required this.label, required this.showNet});

  final String label;
  final bool showNet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: AppTypography.labelMedium),
          ),
          const Expanded(
            child: Text(
              ReportsStrings.incomeColumn,
              style: AppTypography.labelMedium,
              textAlign: TextAlign.end,
            ),
          ),
          const Expanded(
            child: Text(
              ReportsStrings.expenseColumn,
              style: AppTypography.labelMedium,
              textAlign: TextAlign.end,
            ),
          ),
          if (showNet)
            const Expanded(
              child: Text(
                ReportsStrings.netLabel,
                style: AppTypography.labelMedium,
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRowTile extends StatelessWidget {
  const _CategoryRowTile({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final Money income;
  final Money expense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing8,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTypography.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              income.isPositive
                  ? AppFormatters.amountCompact(income.asDouble)
                  : '—',
              style: AppTypography.bodySmall.copyWith(
                color:
                    income.isPositive ? AppColors.income : AppColors.disabled,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            child: Text(
              expense.isPositive
                  ? AppFormatters.amountCompact(expense.asDouble)
                  : '—',
              style: AppTypography.bodySmall.copyWith(
                color:
                    expense.isPositive ? AppColors.expense : AppColors.disabled,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyRowTile extends StatelessWidget {
  const _MonthlyRowTile({
    required this.label,
    required this.income,
    required this.expense,
    required this.net,
  });

  final String label;
  final Money income;
  final Money expense;
  final Money net;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing8,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTypography.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              income.isPositive
                  ? AppFormatters.amountCompact(income.asDouble)
                  : '—',
              style: AppTypography.bodySmall.copyWith(
                color:
                    income.isPositive ? AppColors.income : AppColors.disabled,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            child: Text(
              expense.isPositive
                  ? AppFormatters.amountCompact(expense.asDouble)
                  : '—',
              style: AppTypography.bodySmall.copyWith(
                color:
                    expense.isPositive ? AppColors.expense : AppColors.disabled,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            child: Text(
              net.isPositive ? AppFormatters.amountCompact(net.asDouble) : '—',
              style: AppTypography.bodySmall.copyWith(
                color:
                    net.isPositive ? AppColors.primaryDark : AppColors.disabled,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
