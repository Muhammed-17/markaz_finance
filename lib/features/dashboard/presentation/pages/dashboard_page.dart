import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/domain/entities/transaction_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_amount_text.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_page_widgets.dart';
import '../../../transactions/presentation/widgets/month_field.dart'
    show categoryLabel;
import '../../dashboard_strings.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../bloc/dashboard_bloc.dart';

/// صفحة لوحة التحكم: بطاقة الرصيد الرئيسية، مؤشرات سريعة، أرصدة الأظرف،
/// الملخص الشهري التفاعلي (مع اختيار السنة)، آخر الحركات، والتنبيهات.
/// تُعرض داخل الهيكل العام AppShell.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(const DashboardLoadRequested());
  }

  void _refresh() =>
      context.read<DashboardBloc>().add(const DashboardLoadRequested());

  /// سحب للتحديث: ننتظر انتهاء التحميل حتى يختفي المؤشر في وقته.
  Future<void> _pullToRefresh() async {
    final bloc = context.read<DashboardBloc>();
    bloc.add(const DashboardLoadRequested());
    await bloc.stream
        .firstWhere(
          (s) =>
              s.status != DashboardStatus.refreshing &&
              s.status != DashboardStatus.loading,
        )
        .timeout(AppDurations.networkTimeout, onTimeout: () => bloc.state);
  }

  void _selectYear(int year) => context
      .read<DashboardBloc>()
      .add(DashboardLoadRequested(monthlyYear: year));

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state.isLoading && state.summary == null) {
          return const AppLoadingView(message: AppStrings.loading);
        }

        if (state.status == DashboardStatus.failure && state.summary == null) {
          return AppErrorView(
            message: state.failure?.message ?? AppStrings.errorGeneric,
            onRetry: _refresh,
          );
        }

        final summary = state.summary;
        if (summary == null) {
          return const AppEmptyView(message: AppStrings.noDataFound);
        }

        final isRefreshing = state.status == DashboardStatus.refreshing;

        return AppPageScroll(
          onRefresh: _pullToRefresh,
          children: [
            AppPageHeader(
              title: AppStrings.navDashboard,
              subtitle: '${DashboardStrings.pageSubtitle} • '
                  '${AppFormatters.date(DateTime.now())}',
              actions: [
                _RefreshAction(isRefreshing: isRefreshing, onRefresh: _refresh),
              ],
            ),
            const SizedBox(height: AppDimensions.sectionSpacing),
            _HeroBalanceCard(summary: summary),
            const SizedBox(height: AppDimensions.itemSpacing),
            _OverviewTiles(summary: summary),
            const SizedBox(height: AppDimensions.sectionSpacing),
            _EnvelopesSection(summary: summary),
            const SizedBox(height: AppDimensions.sectionSpacing),
            _MonthlyChartCard(
              rows: summary.monthly,
              year: state.effectiveMonthlyYear,
              isUpdating: isRefreshing,
              onYearChanged: _selectYear,
            ),
            const SizedBox(height: AppDimensions.sectionSpacing),
            _RecentTransactionsSection(
              transactions: summary.recentTransactions,
            ),
            const SizedBox(height: AppDimensions.sectionSpacing),
            _AlertsSection(summary: summary),
            const SizedBox(height: AppDimensions.sectionSpacing),
          ],
        );
      },
    );
  }
}

/// زر التحديث في الترويسة (أو مؤشر تحميل أثناء التحديث الهادئ).
class _RefreshAction extends StatelessWidget {
  const _RefreshAction({required this.isRefreshing, required this.onRefresh});

  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isRefreshing) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.spacing12),
        child: SizedBox(
          width: AppDimensions.iconMedium,
          height: AppDimensions.iconMedium,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    return IconButton.filledTonal(
      tooltip: DashboardStrings.refreshTooltip,
      onPressed: onRefresh,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.primary,
      ),
      icon: const Icon(Icons.refresh_rounded),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// الرصيد الرئيسي
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBalanceCard extends StatelessWidget {
  const _HeroBalanceCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final opening = summary.openingBalanceTotal;

    return AppHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppDimensions.spacing40,
                height: AppDimensions.spacing40,
                decoration: BoxDecoration(
                  color: AppColors.onHeroSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.textOnPrimary,
                  size: AppDimensions.iconMedium,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Text(
                  AppStrings.cashBalance,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.onHeroMuted,
                  ),
                ),
              ),
              const AppHeroPill(label: DashboardStrings.allPeriodsSubtitle),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              AppFormatters.money(summary.cashBalance),
              style: AppTypography.displayLarge.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
          if (opening.isPositive) ...[
            const SizedBox(height: AppDimensions.spacing4),
            Text(
              '${DashboardStrings.openingBalanceIncluded} '
              '${AppFormatters.money(opening)}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onHeroMuted,
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.spacing20),
          Row(
            children: [
              Expanded(
                child: AppHeroMetric(
                  label: AppStrings.operatingIncome,
                  value: AppFormatters.money(summary.operatingIncomeTotal),
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: AppHeroMetric(
                  label: AppStrings.expense,
                  value: AppFormatters.money(summary.expenseTotal),
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

// ─────────────────────────────────────────────────────────────────────────────
// المؤشرات السريعة
// ─────────────────────────────────────────────────────────────────────────────

/// تنبيهات اللوحة: أظرف مؤرشفة برصيد غير صفري + سلف نشطة بمتبقٍ غير مسدد.
List<({IconData icon, String message})> _alertsFor(DashboardSummary summary) {
  return [
    for (final envelope in summary.archivedEnvelopesWithBalance)
      (
        icon: Icons.archive_rounded,
        message: DashboardStrings.archivedEnvelopeAlert(
          envelope.name,
          AppFormatters.money(Money.fromUnits(envelope.currentBalance)),
        ),
      ),
    if (summary.activeLoansCount > 0 && summary.loansRemainingTotal.isPositive)
      (
        icon: Icons.request_page_rounded,
        message: DashboardStrings.activeLoansSummaryAlert(
          summary.activeLoansCount,
          AppFormatters.money(summary.loansRemainingTotal),
        ),
      ),
  ];
}

Money _envelopesTotal(DashboardSummary summary) {
  return summary.activeEnvelopes.fold<Money>(
    Money.zero,
    (sum, e) => sum + Money.fromUnits(e.currentBalance),
  );
}

class _OverviewTiles extends StatelessWidget {
  const _OverviewTiles({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final alertsCount = _alertsFor(summary).length;

    return AppResponsiveGrid(
      minItemWidth: 260,
      maxColumns: 3,
      children: [
        AppMetricTile(
          label: AppStrings.loansRemaining,
          value: AppFormatters.money(summary.loansRemainingTotal),
          icon: Icons.request_page_rounded,
          color: AppColors.warning,
          background: AppColors.warningLight,
          valueColor: AppColors.expense,
          subtitle:
              '${summary.activeLoansCount} ${DashboardStrings.loansCountLabel}',
          onTap: () => context.go('/loans'),
        ),
        AppMetricTile(
          label: DashboardStrings.envelopesTotal,
          value: AppFormatters.money(_envelopesTotal(summary)),
          icon: Icons.account_balance_rounded,
          color: AppColors.primary,
          background: AppColors.primaryLight,
          valueColor: AppColors.primaryDark,
          subtitle: '${summary.activeEnvelopes.length} '
              '${DashboardStrings.activeEnvelopesCount}',
          onTap: () => context.go('/envelopes'),
        ),
        AppMetricTile(
          label: DashboardStrings.alertsTileTitle,
          value: AppFormatters.integer(alertsCount),
          icon: alertsCount == 0
              ? Icons.verified_outlined
              : Icons.notifications_active_rounded,
          color: alertsCount == 0 ? AppColors.success : AppColors.warning,
          background:
              alertsCount == 0 ? AppColors.successLight : AppColors.warningLight,
          subtitle: alertsCount == 0
              ? DashboardStrings.noAlerts
              : DashboardStrings.alertsNeedAttention,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// الأظرف
// ─────────────────────────────────────────────────────────────────────────────

/// قسم أرصدة الأظرف النشطة (المؤرشفة تُخفى وتظهر في التنبيهات عند وجود رصيد).
class _EnvelopesSection extends StatelessWidget {
  const _EnvelopesSection({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final envelopes = summary.activeEnvelopes;
    final total = _envelopesTotal(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: AppStrings.envelopesBalances,
          trailing: TextButton(
            onPressed: () => context.go('/envelopes'),
            child: const Text(AppStrings.all),
          ),
        ),
        const SizedBox(height: AppDimensions.itemSpacing),
        if (envelopes.isEmpty)
          const AppEmptyView(
            message: DashboardStrings.noActiveEnvelopes,
            isCompact: true,
          )
        else
          AppResponsiveGrid(
            minItemWidth: 260,
            children: [
              for (final e in envelopes) _EnvelopeCard(envelope: e, total: total),
            ],
          ),
      ],
    );
  }
}

class _EnvelopeCard extends StatelessWidget {
  const _EnvelopeCard({required this.envelope, required this.total});

  final EnvelopeEntity envelope;
  final Money total;

  @override
  Widget build(BuildContext context) {
    final isGeneral = envelope.isGeneral;
    final balance = Money.fromUnits(envelope.currentBalance);
    final share = total.isPositive ? balance.piasters / total.piasters : 0.0;
    final accent = isGeneral ? AppColors.primary : AppColors.secondary;
    final accentLight =
        isGeneral ? AppColors.primaryLight : AppColors.secondaryLight;

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: isGeneral
                    ? Icons.account_balance_rounded
                    : Icons.lock_outline_rounded,
                color: accent,
                background: accentLight,
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      envelope.name,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacing4),
                    AppStatusChip(
                      label: isGeneral
                          ? DashboardStrings.fundTypeGeneral
                          : DashboardStrings.fundTypeRestricted,
                      color: accent,
                      backgroundColor: accentLight,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            AppFormatters.money(balance),
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0).toDouble(),
              minHeight: AppDimensions.spacing8,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            '${AppFormatters.percent(share)} ${DashboardStrings.shareOfTotal}',
            style: AppTypography.labelSmall,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// الملخص الشهري
// ─────────────────────────────────────────────────────────────────────────────

Color _netColor(int piasters) {
  if (piasters > 0) return AppColors.income;
  if (piasters < 0) return AppColors.expense;
  return AppColors.textSecondary;
}

String _netText(int piasters) =>
    AppFormatters.amountSigned(piasters / 100, showSign: true);

/// بطاقة الملخص الشهري: رسم أعمدة تفاعلي (اضغط شهرًا لعرض تفاصيله)
/// مع اختيار السنة وإجماليات السنة.
class _MonthlyChartCard extends StatefulWidget {
  const _MonthlyChartCard({
    required this.rows,
    required this.year,
    required this.isUpdating,
    required this.onYearChanged,
  });

  final List<DashboardMonthlyRow> rows;
  final int year;
  final bool isUpdating;
  final ValueChanged<int> onYearChanged;

  @override
  State<_MonthlyChartCard> createState() => _MonthlyChartCardState();
}

class _MonthlyChartCardState extends State<_MonthlyChartCard> {
  int? _selected;

  @override
  void didUpdateWidget(covariant _MonthlyChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year) _selected = null;
  }

  List<DashboardMonthlyRow> _chartRows() {
    final byMonth = {for (final r in widget.rows) r.forMonth: r};
    return List<DashboardMonthlyRow>.generate(12, (i) {
      final key = '${widget.year}-${(i + 1).toString().padLeft(2, '0')}';
      return byMonth[key] ??
          DashboardMonthlyRow(
            forMonth: key,
            income: Money.zero,
            expense: Money.zero,
          );
    });
  }

  int _defaultIndex(List<DashboardMonthlyRow> rows) {
    final now = DateTime.now();
    if (widget.year == now.year) return now.month - 1;
    final last = rows.lastIndexWhere(
      (r) => r.income.isPositive || r.expense.isPositive,
    );
    return last == -1 ? 11 : last;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _chartRows();
    final maxValue = rows.fold<int>(
      0,
      (max, row) =>
          math.max(max, math.max(row.income.piasters, row.expense.piasters)),
    );
    final hasAnyData = rows.any(
      (r) => r.income.isPositive || r.expense.isPositive,
    );
    final selectedIndex = _selected ?? _defaultIndex(rows);
    final totalIncome =
        rows.fold<Money>(Money.zero, (sum, r) => sum + r.income);
    final totalExpense =
        rows.fold<Money>(Money.zero, (sum, r) => sum + r.expense);
    final currentYear = DateTime.now().year;
    final years = [for (var i = 0; i < 5; i++) currentYear - i];

    return AppCard(
      elevated: true,
      child: AnimatedOpacity(
        opacity: widget.isUpdating ? 0.5 : 1,
        duration: AppDurations.fast,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSectionTitle(
              title: AppStrings.monthlySummary,
              subtitle: DashboardStrings.monthlySubtitle,
              trailing: _YearPicker(
                year: widget.year,
                years: years,
                onSelected: widget.onYearChanged,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Wrap(
              spacing: AppDimensions.spacing8,
              runSpacing: AppDimensions.spacing8,
              children: [
                _TotalPill(
                  label: DashboardStrings.yearTotalIncome,
                  value: AppFormatters.amountCompact(totalIncome.asDouble),
                  color: AppColors.income,
                  background: AppColors.incomeLight,
                ),
                _TotalPill(
                  label: DashboardStrings.yearTotalExpense,
                  value: AppFormatters.amountCompact(totalExpense.asDouble),
                  color: AppColors.expense,
                  background: AppColors.expenseLight,
                ),
                _TotalPill(
                  label: DashboardStrings.yearNet,
                  value: _netText(totalIncome.piasters - totalExpense.piasters),
                  color: _netColor(totalIncome.piasters - totalExpense.piasters),
                  background: AppColors.surfaceAlt,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing20),
            if (!hasAnyData)
              const AppEmptyView(
                message: DashboardStrings.monthlySectionEmpty,
                isCompact: true,
              )
            else ...[
              _MonthlyBars(
                rows: rows,
                maxValue: maxValue,
                selectedIndex: selectedIndex,
                onSelected: (index) => setState(() => _selected = index),
              ),
              const SizedBox(height: AppDimensions.spacing16),
              _SelectedMonthDetails(row: rows[selectedIndex]),
            ],
          ],
        ),
      ),
    );
  }
}

class _YearPicker extends StatelessWidget {
  const _YearPicker({
    required this.year,
    required this.years,
    required this.onSelected,
  });

  final int year;
  final List<int> years;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: year,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final y in years)
          PopupMenuItem<int>(value: y, child: Text('$y')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing12,
          vertical: AppDimensions.spacing8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: AppDimensions.iconSmall + 2,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppDimensions.spacing4),
            Text('$year', style: AppTypography.titleMedium),
            const Icon(
              Icons.expand_more_rounded,
              size: AppDimensions.iconMedium - 2,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalPill extends StatelessWidget {
  const _TotalPill({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.labelMedium),
          const SizedBox(width: AppDimensions.spacing8),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// أعمدة الأشهر الاثني عشر؛ على الشاشات الضيقة تُمرَّر أفقيًا.
class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({
    required this.rows,
    required this.maxValue,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<DashboardMonthlyRow> rows;
  final int maxValue;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = math.max(
          AppDimensions.chartMinSlotWidth,
          constraints.maxWidth / 12,
        );

        final chart = SizedBox(
          width: slot * 12,
          child: Stack(
            children: [
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: AppDimensions.chartHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [_GridLine(), _GridLine(), _GridLine()],
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    SizedBox(
                      width: slot,
                      child: _MonthColumn(
                        monthName: AppDateTimeUtils.monthName(i + 1),
                        row: rows[i],
                        maxValue: maxValue,
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );

        if (slot * 12 <= constraints.maxWidth + 0.5) return chart;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: chart,
        );
      },
    );
  }
}

class _GridLine extends StatelessWidget {
  const _GridLine();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.border);
}

class _MonthColumn extends StatelessWidget {
  const _MonthColumn({
    required this.monthName,
    required this.row,
    required this.maxValue,
    required this.selected,
    required this.onTap,
  });

  final String monthName;
  final DashboardMonthlyRow row;
  final int maxValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight.withAlpha(120) : null,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          child: Column(
            children: [
              SizedBox(
                height: AppDimensions.chartHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Bar(
                      value: row.income,
                      maxValue: maxValue,
                      color: AppColors.income,
                    ),
                    const SizedBox(width: AppDimensions.spacing2),
                    _Bar(
                      value: row.expense,
                      maxValue: maxValue,
                      color: AppColors.expense,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing8,
                  vertical: AppDimensions.spacing2,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusExtraLarge),
                ),
                child: Text(
                  monthName,
                  style: AppTypography.labelSmall.copyWith(
                    color: selected
                        ? AppColors.textOnPrimary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final Money value;
  final int maxValue;
  final Color color;

  static const double _minHeight = 3;
  static const double _emptyHeight = 2;

  @override
  Widget build(BuildContext context) {
    final hasValue = maxValue > 0 && value.piasters > 0;
    final target = hasValue
        ? math.max(
            _minHeight,
            (value.piasters / maxValue) * AppDimensions.chartHeight,
          )
        : _emptyHeight;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
      builder: (context, height, _) => Container(
        width: AppDimensions.chartBarWidth,
        height: height,
        decoration: BoxDecoration(
          color: hasValue ? color : AppColors.border,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.spacing4),
          ),
        ),
      ),
    );
  }
}

class _SelectedMonthDetails extends StatelessWidget {
  const _SelectedMonthDetails({required this.row});

  final DashboardMonthlyRow row;

  @override
  Widget build(BuildContext context) {
    final net = row.income.piasters - row.expense.piasters;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppFormatters.monthLabel(row.forMonth),
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              Expanded(
                child: _MiniFigure(
                  label: AppStrings.incomeShort,
                  value: AppFormatters.amountCompact(row.income.asDouble),
                  color: AppColors.income,
                ),
              ),
              Expanded(
                child: _MiniFigure(
                  label: AppStrings.expenseShort,
                  value: AppFormatters.amountCompact(row.expense.asDouble),
                  color: AppColors.expense,
                ),
              ),
              Expanded(
                child: _MiniFigure(
                  label: DashboardStrings.selectedMonthNet,
                  value: _netText(net),
                  color: _netColor(net),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniFigure extends StatelessWidget {
  const _MiniFigure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: AppDimensions.spacing8,
              height: AppDimensions.spacing8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppDimensions.spacing4),
            Text(label, style: AppTypography.labelMedium),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing2),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// آخر الحركات
// ─────────────────────────────────────────────────────────────────────────────

/// قسم آخر الحركات المالية (آخر 5 حركات) داخل بطاقة واحدة.
class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({required this.transactions});

  final List<TransactionEntity> transactions;

  @override
  Widget build(BuildContext context) {
    final items = transactions.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(
          title: AppStrings.recentTransactions,
          trailing: TextButton.icon(
            onPressed: () => context.go('/transactions'),
            icon: const Icon(Icons.list_rounded, size: AppDimensions.iconMedium),
            label: const Text(DashboardStrings.viewAllTransactions),
          ),
        ),
        const SizedBox(height: AppDimensions.itemSpacing),
        if (items.isEmpty)
          const AppEmptyView(
            message: AppStrings.noDataFound,
            icon: Icons.receipt_long_outlined,
            isCompact: true,
          )
        else
          AppCard(
            elevated: true,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _RecentTransactionTile(transaction: items[i]),
                    if (i != items.length - 1)
                      const Divider(
                        indent: AppDimensions.cardPadding,
                        endIndent: AppDimensions.cardPadding,
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.transaction});

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final background =
        isIncome ? AppColors.incomeLight : AppColors.expenseLight;

    return InkWell(
      onTap: () => context.go('/transactions/${transaction.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.cardPadding,
          vertical: AppDimensions.spacing12,
        ),
        child: Row(
          children: [
            AppIconBadge(
              icon: isIncome
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: color,
              background: background,
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.name,
                    style: AppTypography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.spacing2),
                  Text(
                    '${categoryLabel(transaction.category)} • '
                    '${AppFormatters.date(transaction.createdAt)}',
                    style: AppTypography.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacing12),
            AppAmountText(
              amount: transaction.amount,
              isIncome: isIncome,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// التنبيهات
// ─────────────────────────────────────────────────────────────────────────────

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final alerts = _alertsFor(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionTitle(title: DashboardStrings.alertsSectionTitle),
        const SizedBox(height: AppDimensions.itemSpacing),
        if (alerts.isEmpty)
          const AppCard(
            backgroundColor: AppColors.successLight,
            borderColor: AppColors.successLight,
            child: Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: AppColors.success,
                  size: AppDimensions.iconMedium,
                ),
                SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Text(
                    DashboardStrings.noAlerts,
                    style: AppTypography.titleMedium,
                  ),
                ),
              ],
            ),
          )
        else
          for (final alert in alerts)
            Padding(
              padding:
                  const EdgeInsets.only(bottom: AppDimensions.itemSpacing),
              child: _AlertTile(icon: alert.icon, message: alert.message),
            ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.warningLight,
      borderColor: AppColors.warningLight,
      child: Row(
        children: [
          Icon(icon, color: AppColors.warning, size: AppDimensions.iconMedium),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(child: Text(message, style: AppTypography.bodyMedium)),
        ],
      ),
    );
  }
}
