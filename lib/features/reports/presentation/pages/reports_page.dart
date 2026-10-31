import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_page_widgets.dart';
import '../../../transactions/presentation/widgets/month_field.dart'
    show categoryLabel;
import '../../domain/entities/report_filter.dart';
import '../../domain/entities/report_result.dart';
import '../../domain/usecases/reports_usecases.dart';
import '../../reports_strings.dart';
import '../bloc/reports_bloc.dart';
import '../widgets/report_filters_bar.dart';

/// صفحة التقارير المالية: شريط فلاتر + ملخص تنفيذي بارز + مؤشرات + تفصيل
/// بالتصنيف (مع حصص نسبية) وبالشهر (مع الصافي). تُعرض داخل AppShell.
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

  Future<void> _copySummary(ReportResult result) async {
    await Clipboard.setData(ClipboardData(text: _summaryText(result)));
    if (!mounted) return;
    showAppSnackBar(context, message: ReportsStrings.summaryCopied);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsBloc, ReportsState>(
      builder: (context, state) {
        final result =
            state.status == ReportsStatus.success ? state.result : null;

        return AppPageScroll(
          children: [
            AppPageHeader(
              title: AppStrings.navReports,
              subtitle: ReportsStrings.pageSubtitle,
              actions: [
                if (result != null)
                  IconButton.filledTonal(
                    tooltip: ReportsStrings.copySummary,
                    onPressed: () => _copySummary(result),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.copy_all_rounded),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.sectionSpacing),
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
        );
      },
    );
  }
}

/// نص ملخص التقرير للنسخ (مشاركة سريعة).
String _summaryText(ReportResult r) {
  final net = r.operatingIncomeTotal.piasters - r.operatingExpenseTotal.piasters;
  return [
    ReportsStrings.reportsTitle,
    '${AppStrings.cashBalance}: ${AppFormatters.money(r.cashBalance)}',
    '${AppStrings.openingBalance}: ${AppFormatters.money(r.openingBalanceTotal)}',
    '${AppStrings.operatingIncome}: ${AppFormatters.money(r.operatingIncomeTotal)}',
    '${AppStrings.operatingExpense}: ${AppFormatters.money(r.operatingExpenseTotal)}',
    '${ReportsStrings.netOperating}: ${AppFormatters.amountSigned(net / 100, showSign: true)}',
    '${ReportsStrings.loanDisbursementsShort}: ${AppFormatters.money(r.loanDisbursementsTotal)}',
    '${ReportsStrings.loanRepaymentsShort}: ${AppFormatters.money(r.loanRepaymentsTotal)}',
    '${ReportsStrings.transactionsCountLabel}: ${AppFormatters.integer(r.transactionsCount)}',
    '${ReportsStrings.generatedAtLabel} ${AppFormatters.dateTime(r.generatedAt)}',
  ].join('\n');
}

Color _signColor(int piasters) {
  if (piasters > 0) return AppColors.income;
  if (piasters < 0) return AppColors.expense;
  return AppColors.textSecondary;
}

String _signText(int piasters) =>
    AppFormatters.amountSigned(piasters / 100, showSign: true);

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

/// جسم التقرير: البطاقة البارزة + المؤشرات + التفاصيل.
class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.result});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportHero(result: result),
        const SizedBox(height: AppDimensions.itemSpacing),
        _KpiGrid(result: result),
        const SizedBox(height: AppDimensions.sectionSpacing),
        _CategoryBreakdownCard(rows: result.categoryBreakdown),
        const SizedBox(height: AppDimensions.sectionSpacing),
        _MonthlyBreakdownCard(rows: result.monthlyBreakdown),
        const SizedBox(height: AppDimensions.sectionSpacing),
        _TransfersCard(result: result),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// الملخص البارز
// ─────────────────────────────────────────────────────────────────────────────

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.result});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    return AppHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ReportsStrings.summarySection} • ${AppStrings.cashBalance}',
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.onHeroMuted,
                  ),
                ),
              ),
              AppHeroPill(
                label: '${AppFormatters.integer(result.transactionsCount)} '
                    '${ReportsStrings.transactionsUnit}',
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              AppFormatters.money(result.cashBalance),
              style: AppTypography.displayLarge.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            '${ReportsStrings.generatedAtLabel} '
            '${AppFormatters.dateTime(result.generatedAt)}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onHeroMuted,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing20),
          Row(
            children: [
              Expanded(
                child: AppHeroMetric(
                  label: AppStrings.operatingIncome,
                  value: AppFormatters.money(result.operatingIncomeTotal),
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: AppHeroMetric(
                  label: AppStrings.operatingExpense,
                  value: AppFormatters.money(result.operatingExpenseTotal),
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.result});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    final net =
        result.operatingIncomeTotal.piasters - result.operatingExpenseTotal.piasters;

    return AppResponsiveGrid(
      minItemWidth: 240,
      children: [
        AppMetricTile(
          label: AppStrings.openingBalance,
          value: AppFormatters.money(result.openingBalanceTotal),
          icon: Icons.flag_rounded,
          color: AppColors.info,
          background: AppColors.infoLight,
        ),
        AppMetricTile(
          label: ReportsStrings.netOperating,
          value: _signText(net),
          icon: net < 0
              ? Icons.trending_down_rounded
              : Icons.trending_up_rounded,
          color: _signColor(net),
          background: net < 0 ? AppColors.expenseLight : AppColors.incomeLight,
          valueColor: _signColor(net),
        ),
        AppMetricTile(
          label: ReportsStrings.loanDisbursementsShort,
          value: AppFormatters.money(result.loanDisbursementsTotal),
          icon: Icons.request_page_rounded,
          color: AppColors.warning,
          background: AppColors.warningLight,
          valueColor: AppColors.expense,
          subtitle: ReportsStrings.includedInExpenses,
        ),
        AppMetricTile(
          label: ReportsStrings.loanRepaymentsShort,
          value: AppFormatters.money(result.loanRepaymentsTotal),
          icon: Icons.price_check_rounded,
          color: AppColors.success,
          background: AppColors.successLight,
          valueColor: AppColors.income,
          subtitle: ReportsStrings.includedInIncome,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// التفصيل حسب التصنيف
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBreakdownCard extends StatefulWidget {
  const _CategoryBreakdownCard({required this.rows});

  final List<ReportCategoryRow> rows;

  @override
  State<_CategoryBreakdownCard> createState() => _CategoryBreakdownCardState();
}

class _CategoryBreakdownCardState extends State<_CategoryBreakdownCard> {
  late bool _incomeView;

  @override
  void initState() {
    super.initState();
    final hasExpense = widget.rows.any((r) => r.expense.isPositive);
    final hasIncome = widget.rows.any((r) => r.income.isPositive);
    _incomeView = !hasExpense && hasIncome;
  }

  @override
  Widget build(BuildContext context) {
    final color = _incomeView ? AppColors.income : AppColors.expense;
    final items = [
      for (final row in widget.rows)
        if ((_incomeView ? row.income : row.expense).isPositive)
          (
            label: categoryLabel(row.category),
            value: _incomeView ? row.income : row.expense,
          ),
    ]..sort((a, b) => b.value.piasters.compareTo(a.value.piasters));

    final total = items.fold<Money>(Money.zero, (sum, e) => sum + e.value);
    final maxValue = items.isEmpty ? 0 : items.first.value.piasters;

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionTitle(title: ReportsStrings.categorySection),
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              AppChoiceChip(
                label: ReportsStrings.expenseTab,
                icon: Icons.north_east_rounded,
                selected: !_incomeView,
                onTap: () => setState(() => _incomeView = false),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              AppChoiceChip(
                label: ReportsStrings.incomeTab,
                icon: Icons.south_west_rounded,
                selected: _incomeView,
                onTap: () => setState(() => _incomeView = true),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          if (items.isEmpty)
            const AppEmptyView(
              message: ReportsStrings.noCategoryData,
              isCompact: true,
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      ReportsStrings.totalLabel,
                      style: AppTypography.titleMedium,
                    ),
                  ),
                  Text(
                    AppFormatters.money(total),
                    style: AppTypography.titleLarge.copyWith(color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            for (final item in items)
              _CategoryBarRow(
                label: item.label,
                value: item.value,
                total: total,
                maxValue: maxValue,
                color: color,
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBarRow extends StatelessWidget {
  const _CategoryBarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final Money value;
  final Money total;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fill = maxValue <= 0 ? 0.0 : value.piasters / maxValue;
    final share = total.isPositive ? value.piasters / total.piasters : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                AppFormatters.amountCompact(value.asDouble),
                style: AppTypography.titleMedium.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                  child: LinearProgressIndicator(
                    value: fill.clamp(0.0, 1.0).toDouble(),
                    minHeight: AppDimensions.spacing8,
                    backgroundColor: AppColors.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              SizedBox(
                width: AppDimensions.spacing48,
                child: Text(
                  AppFormatters.percent(share),
                  style: AppTypography.labelSmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// التفصيل حسب الشهر
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyBreakdownCard extends StatelessWidget {
  const _MonthlyBreakdownCard({required this.rows});

  final List<ReportMonthlyRow> rows;

  @override
  Widget build(BuildContext context) {
    var maxValue = 0;
    for (final row in rows) {
      if (row.income.piasters > maxValue) maxValue = row.income.piasters;
      if (row.expense.piasters > maxValue) maxValue = row.expense.piasters;
    }

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionTitle(title: ReportsStrings.monthlySection),
          const SizedBox(height: AppDimensions.spacing12),
          if (rows.isEmpty)
            const AppEmptyView(
              message: AppStrings.noDataFound,
              isCompact: true,
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              _MonthlyRowTile(row: rows[i], maxValue: maxValue),
              if (i != rows.length - 1) const Divider(),
            ],
        ],
      ),
    );
  }
}

class _MonthlyRowTile extends StatelessWidget {
  const _MonthlyRowTile({required this.row, required this.maxValue});

  final ReportMonthlyRow row;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    // الصافي يُحسب هنا بالقروش مع الإشارة (ReportMonthlyRow.net يثبّته على الصفر).
    final net = row.income.piasters - row.expense.piasters;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppFormatters.monthLabel(row.forMonth),
                  style: AppTypography.titleMedium,
                ),
              ),
              const Text(
                '${ReportsStrings.netLabel}: ',
                style: AppTypography.labelMedium,
              ),
              Text(
                _signText(net),
                style: AppTypography.titleMedium.copyWith(
                  color: _signColor(net),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          _FlatBar(
            label: ReportsStrings.incomeColumn,
            value: row.income,
            maxValue: maxValue,
            color: AppColors.income,
          ),
          const SizedBox(height: AppDimensions.spacing4),
          _FlatBar(
            label: ReportsStrings.expenseColumn,
            value: row.expense,
            maxValue: maxValue,
            color: AppColors.expense,
          ),
        ],
      ),
    );
  }
}

class _FlatBar extends StatelessWidget {
  const _FlatBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final Money value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fill = maxValue <= 0 ? 0.0 : value.piasters / maxValue;

    return Row(
      children: [
        SizedBox(
          width: AppDimensions.spacing40,
          child: Text(label, style: AppTypography.labelSmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            child: LinearProgressIndicator(
              value: fill.clamp(0.0, 1.0).toDouble(),
              minHeight: AppDimensions.spacing8,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacing8),
        SizedBox(
          width: 96,
          child: Text(
            value.isPositive
                ? AppFormatters.amountCompact(value.asDouble)
                : '—',
            style: AppTypography.labelMedium.copyWith(
              color: value.isPositive ? color : AppColors.disabled,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// تحويلات الأظرف
// ─────────────────────────────────────────────────────────────────────────────

class _TransfersCard extends StatelessWidget {
  const _TransfersCard({required this.result});

  final ReportResult result;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.infoLight,
      borderColor: AppColors.infoLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.info,
                size: AppDimensions.iconMedium,
              ),
              SizedBox(width: AppDimensions.spacing8),
              Text(
                ReportsStrings.internalTransfers,
                style: AppTypography.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Wrap(
            spacing: AppDimensions.spacing24,
            runSpacing: AppDimensions.spacing8,
            children: [
              _TransferFigure(
                label: ReportsStrings.transfersOut,
                value: AppFormatters.money(result.transfersOutTotal),
              ),
              _TransferFigure(
                label: ReportsStrings.transfersIn,
                value: AppFormatters.money(result.transfersInTotal),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          const Text(
            ReportsStrings.transfersNote,
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TransferFigure extends StatelessWidget {
  const _TransferFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.labelMedium),
        Text(value, style: AppTypography.titleLarge),
      ],
    );
  }
}
