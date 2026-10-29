import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

import '../../../../core/constants/app_dimensions.dart';

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

import '../../../../core/widgets/app_stat_card.dart';

import '../../../../core/constants/app_strings.dart';

import '../../../transactions/presentation/widgets/month_field.dart'

    show categoryLabel;

import '../../dashboard_strings.dart';

import '../../domain/entities/dashboard_summary.dart';

import '../bloc/dashboard_bloc.dart';

/// صفحة لوحة التحكم: المؤشرات المالية، أرصدة الأظرف، الملخص الشهري،

/// آخر الحركات، والتنبيهات. تُعرض داخل الهيكل العام AppShell.

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

        return SingleChildScrollView(

          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 360
                ? 10
                : AppDimensions.pagePaddingMobile,
            vertical: 16,
          ),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              _PageHeader(

                summary: summary,

                isRefreshing: state.status == DashboardStatus.refreshing,

                onRefresh: _refresh,

              ),

              const SizedBox(height: AppDimensions.sectionSpacing),

              _StatsGrid(summary: summary),

              const SizedBox(height: AppDimensions.sectionSpacing),

              _EnvelopesSection(summary: summary),

              const SizedBox(height: AppDimensions.sectionSpacing),

              _MonthlyChartSection(

                rows: summary.monthly,

                year: state.effectiveMonthlyYear,

              ),

              const SizedBox(height: AppDimensions.sectionSpacing),

              _RecentTransactionsSection(

                transactions: summary.recentTransactions,

              ),

              const SizedBox(height: AppDimensions.sectionSpacing),

              _AlertsSection(summary: summary),

              const SizedBox(height: AppDimensions.sectionSpacing),

            ],

          ),

        );

      },

    );

  }

}

/// بطاقة البداية: الرصيد المتاح وأقرب الإجراءات في مساحة واحدة واضحة.

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.summary,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final DashboardSummary summary;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 400;

        return Container(
          padding: EdgeInsets.all(compact ? 16 : 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(
              compact ? 20 : AppDimensions.radiusExtraLarge,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'نظرة عامة',
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: DashboardStrings.refreshTooltip,
                    onPressed: isRefreshing ? null : onRefresh,
                    color: AppColors.textOnPrimary,
                    icon: isRefreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.cashBalance,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  AppFormatters.money(summary.cashBalance),
                  style: AppTypography.displayLarge.copyWith(
                    color: AppColors.textOnPrimary,
                    fontSize: compact ? 28 : 34,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroMetric(
                    label: AppStrings.incomeShort,
                    value: AppFormatters.money(summary.operatingIncomeTotal),
                    icon: Icons.south_west_rounded,
                  ),
                  _HeroMetric(
                    label: AppStrings.expenseShort,
                    value: AppFormatters.money(summary.expenseTotal),
                    icon: Icons.north_east_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => context.go('/transactions'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    backgroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('عرض الحركات المالية'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroMetric extends StatelessWidget {

  const _HeroMetric({

    required this.label,

    required this.value,

    required this.icon,

  });

  final String label;

  final String value;

  final IconData icon;

  @override

  Widget build(BuildContext context) => Container(

        padding: const EdgeInsets.symmetric(

          horizontal: AppDimensions.spacing12,

          vertical: AppDimensions.spacing8,

        ),

        decoration: BoxDecoration(

          color: AppColors.textOnPrimary.withValues(alpha: 0.12),

          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),

          border: Border.all(

            color: AppColors.textOnPrimary.withValues(alpha: 0.16),

          ),

        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(

              icon,

              size: AppDimensions.iconSmall,

              color: AppColors.textOnPrimary,

            ),

            const SizedBox(width: AppDimensions.spacing4),

            Text(

              '$label: $value',

              style: AppTypography.labelMedium.copyWith(

                color: AppColors.textOnPrimary,

              ),

            ),

          ],

        ),

      );

}

/// شبكة المؤشرات الأربعة الرئيسية.

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columns = availableWidth >= 1000
            ? 4
            : availableWidth >= 340
                ? 2
                : 1;
        const spacing = 12.0;
        final cardWidth =
            (availableWidth - spacing * (columns - 1)) / columns;

        final cards = <Widget>[
          AppStatCard(
            title: AppStrings.cashBalance,
            value: AppFormatters.money(summary.cashBalance),
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppColors.textOnPrimary,
            iconBackground: AppColors.primary,
            valueColor: AppColors.primaryDark,
            subtitle: DashboardStrings.allPeriodsSubtitle,
          ),
          AppStatCard(
            title: AppStrings.operatingIncome,
            value: AppFormatters.money(summary.operatingIncomeTotal),
            icon: Icons.south_west_rounded,
            iconColor: AppColors.income,
            iconBackground: AppColors.incomeLight,
            valueColor: AppColors.income,
            subtitle: DashboardStrings.allPeriodsSubtitle,
          ),
          AppStatCard(
            title: AppStrings.expense,
            value: AppFormatters.money(summary.expenseTotal),
            icon: Icons.north_east_rounded,
            iconColor: AppColors.expense,
            iconBackground: AppColors.expenseLight,
            valueColor: AppColors.expense,
            subtitle: DashboardStrings.allPeriodsSubtitle,
          ),
          AppStatCard(
            title: AppStrings.loansRemaining,
            value: AppFormatters.money(summary.loansRemainingTotal),
            icon: Icons.request_page_rounded,
            iconColor: AppColors.expense,
            iconBackground: AppColors.warningLight,
            valueColor: AppColors.expense,
            subtitle:
                '${summary.activeLoansCount} ${DashboardStrings.loansCountLabel}',
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

class _EnvelopesSection extends StatelessWidget {
  const _EnvelopesSection({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final envelopes = summary.activeEnvelopes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          AppStrings.envelopesBalances,
          style: AppTypography.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (envelopes.isEmpty)
          const AppEmptyView(
            message: DashboardStrings.noActiveEnvelopes,
            isCompact: true,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? 2 : 1;
              const spacing = 12.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: envelopes
                    .map(
                      (envelope) => SizedBox(
                        width: itemWidth,
                        child: _EnvelopeCard(envelope: envelope),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _EnvelopeCard extends StatelessWidget {
  const _EnvelopeCard({required this.envelope});

  final EnvelopeEntity envelope;

  @override
  Widget build(BuildContext context) {
    final isGeneral = envelope.isGeneral;

    return AppCardLike(
      child: Row(
        children: [
          Container(
            width: AppDimensions.iconLarge + AppDimensions.spacing8,
            height: AppDimensions.iconLarge + AppDimensions.spacing8,
            decoration: BoxDecoration(
              color: isGeneral ? AppColors.primaryLight : AppColors.secondaryLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Icon(
              isGeneral
                  ? Icons.account_balance_rounded
                  : Icons.lock_outline_rounded,
              color: isGeneral ? AppColors.primary : AppColors.secondary,
              size: AppDimensions.iconMedium,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  envelope.name,
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: AppDimensions.spacing4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    AppFormatters.money(
                      Money.fromUnits(envelope.currentBalance),
                    ),
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing4),
                AppStatusChip(
                  label: isGeneral
                      ? DashboardStrings.fundTypeGeneral
                      : DashboardStrings.fundTypeRestricted,
                  color: isGeneral ? AppColors.primary : AppColors.secondary,
                  backgroundColor: isGeneral
                      ? AppColors.primaryLight
                      : AppColors.secondaryLight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// قسم الملخص الشهري: رسم أعمدة بسيط بدون حزم خارجية

/// (عمودان متجاوران لكل شهر بارتفاع نسبي وأرقام مختصرة).

class _MonthlyChartSection extends StatelessWidget {

  const _MonthlyChartSection({required this.rows, required this.year});

  final List<DashboardMonthlyRow> rows;

  final int year;

  static const double _chartMaxHeight = 88;

  static const double _barMinHeight = 4;

  static const double _barRowExtraHeight = 20;

  @override

  Widget build(BuildContext context) {

    final byMonth = {for (final r in rows) r.forMonth: r};

    final chartRows = List<DashboardMonthlyRow>.generate(12, (i) {

      final key = '$year-${(i + 1).toString().padLeft(2, '0')}';

      return byMonth[key] ??

          DashboardMonthlyRow(

            forMonth: key,

            income: Money.zero,

            expense: Money.zero,

          );

    });

    final maxValue = chartRows.fold<int>(

      0,

      (max, row) =>

          math.max(max, math.max(row.income.piasters, row.expense.piasters)),

    );

    final hasAnyData = chartRows.any(

      (r) => r.income.isPositive || r.expense.isPositive,

    );

    return ConstrainedBox(

      constraints: const BoxConstraints(maxWidth: 720),

      child: AppCard(

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            const Text(AppStrings.monthlySummary,

                style: AppTypography.headlineSmall),

            const SizedBox(height: AppDimensions.spacing4),

            const _ChartLegend(),

            const SizedBox(height: AppDimensions.spacing12),

            if (!hasAnyData)

              const AppEmptyView(

                message: DashboardStrings.monthlySectionEmpty,

                isCompact: true,

              )

            else

              ...List.generate(chartRows.length, (index) {

                final row = chartRows[index];

                return Padding(

                  padding: const EdgeInsets.symmetric(

                    vertical: AppDimensions.spacing4,

                  ),

                  child: _MonthBarRow(

                    monthName: AppDateTimeUtils.monthName(index + 1),

                    row: row,

                    maxValue: maxValue,

                  ),

                );

              }),

          ],

        ),

      ),

    );

  }

}

/// صف واحد في الرسم: اسم الشهر + عمودا الإيراد والمصروف.

class _MonthBarRow extends StatelessWidget {

  const _MonthBarRow({

    required this.monthName,

    required this.row,

    required this.maxValue,

  });

  final String monthName;

  final DashboardMonthlyRow row;

  final int maxValue;

  @override

  Widget build(BuildContext context) {

    return Row(

      crossAxisAlignment: CrossAxisAlignment.end,

      children: [

        SizedBox(

          width: 48,

          child: Text(

            monthName,

            style: AppTypography.labelSmall,

            overflow: TextOverflow.ellipsis,

          ),

        ),

        const SizedBox(width: AppDimensions.spacing12),

        Expanded(

          child: Row(

            crossAxisAlignment: CrossAxisAlignment.end,

            children: [

              Expanded(

                child: _MonthBar(

                  value: row.income,

                  maxValue: maxValue,

                  color: AppColors.income,

                ),

              ),

              const SizedBox(width: AppDimensions.spacing4),

              Expanded(

                child: _MonthBar(

                  value: row.expense,

                  maxValue: maxValue,

                  color: AppColors.expense,

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

}

class _MonthBar extends StatelessWidget {

  const _MonthBar({

    required this.value,

    required this.maxValue,

    required this.color,

  });

  final Money value;

  final int maxValue;

  final Color color;

  @override

  Widget build(BuildContext context) {

    final barHeight = maxValue <= 0 || value.piasters <= 0

        ? _MonthlyChartSection._barMinHeight

        : math.max(

            _MonthlyChartSection._barMinHeight,

            (value.piasters / maxValue) * _MonthlyChartSection._chartMaxHeight,

          );

    return SizedBox(

      height: _MonthlyChartSection._chartMaxHeight +

          _MonthlyChartSection._barRowExtraHeight,

      child: Column(

        mainAxisAlignment: MainAxisAlignment.end,

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Text(

            AppFormatters.amountCompact(value.asDouble),

            style: AppTypography.labelSmall,

            textAlign: TextAlign.center,

            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,

          ),

          const SizedBox(height: AppDimensions.spacing2),

          Center(

            child: Container(

              width: 18,

              height: barHeight,

              decoration: BoxDecoration(

                color: value.isPositive ? color : AppColors.surfaceAlt,

                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),

              ),

            ),

          ),

        ],

      ),

    );

  }

}

/// مفتاح ألوان الرسم (إيراد/مصروف).

class _ChartLegend extends StatelessWidget {

  const _ChartLegend();

  @override

  Widget build(BuildContext context) {

    return Row(

      children: [

        _legendDot(AppColors.income),

        const SizedBox(width: AppDimensions.spacing4),

        const Text(AppStrings.incomeShort, style: AppTypography.labelSmall),

        const SizedBox(width: AppDimensions.spacing16),

        _legendDot(AppColors.expense),

        const SizedBox(width: AppDimensions.spacing4),

        const Text(AppStrings.expenseShort, style: AppTypography.labelSmall),

      ],

    );

  }

  Widget _legendDot(Color color) => Container(

        width: AppDimensions.spacing12,

        height: AppDimensions.spacing12,

        decoration: BoxDecoration(

          color: color,

          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),

        ),

      );

}

/// قسم آخر الحركات المالية (آخر 5 حركات).

class _RecentTransactionsSection extends StatelessWidget {

  const _RecentTransactionsSection({required this.transactions});

  final List<TransactionEntity> transactions;

  @override

  Widget build(BuildContext context) {

    final items = transactions.take(5).toList();

    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Row(

          children: [

            const Expanded(

              child: Text(AppStrings.recentTransactions,

                  style: AppTypography.headlineSmall),

            ),

            TextButton.icon(

              onPressed: () => context.go('/transactions'),

              icon: const Icon(Icons.list_rounded,

                  size: AppDimensions.iconMedium),

              label: const Text(DashboardStrings.viewAllTransactions),

            ),

          ],

        ),

        const SizedBox(height: AppDimensions.itemSpacing),

        if (items.isEmpty)

          const AppEmptyView(

            message: AppStrings.noDataFound,

            icon: Icons.receipt_long_outlined,

            isCompact: true,

          )

        else

          ...items.map(

            (t) => Padding(

              padding: const EdgeInsets.only(bottom: AppDimensions.itemSpacing),

              child: _RecentTransactionTile(transaction: t),

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

    return AppCardLike(

      onTap: () => context.go('/transactions/${transaction.id}'),

      padding: const EdgeInsets.symmetric(

        horizontal: AppDimensions.cardPadding,

        vertical: AppDimensions.spacing12,

      ),

      child: Row(

        children: [

          Container(

            width: AppDimensions.iconLarge + AppDimensions.spacing12,

            height: AppDimensions.iconLarge + AppDimensions.spacing12,

            decoration: BoxDecoration(

              color: background,

              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),

            ),

            child: Icon(

              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,

              color: color,

              size: AppDimensions.iconMedium,

            ),

          ),

          const SizedBox(width: AppDimensions.spacing12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              mainAxisSize: MainAxisSize.min,

              children: [

                Text(

                  transaction.name,

                  style: AppTypography.titleMedium,

                  overflow: TextOverflow.ellipsis,

                ),

                const SizedBox(height: AppDimensions.spacing2),

                Text(

                  '${categoryLabel(transaction.category)} • '

                  '${AppFormatters.date(transaction.createdAt)}',

                  style: AppTypography.labelSmall,

                  overflow: TextOverflow.ellipsis,

                ),

              ],

            ),

          ),

          const SizedBox(width: AppDimensions.spacing12),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 115),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: AppAmountText(
                amount: transaction.amount,
                isIncome: isIncome,
              ),
            ),
          ),

        ],

      ),

    );

  }

}

/// قسم التنبيهات: أظرف مؤرشفة برصيد غير صفري + سلف نشطة بمتبقٍ غير مسدد.

class _AlertsSection extends StatelessWidget {

  const _AlertsSection({required this.summary});

  final DashboardSummary summary;

  @override

  Widget build(BuildContext context) {

    final alerts = <_AlertTile>[

      for (final envelope in summary.archivedEnvelopesWithBalance)

        _AlertTile(

          icon: Icons.archive_rounded,

          message: DashboardStrings.archivedEnvelopeAlert(

            envelope.name,

            AppFormatters.money(Money.fromUnits(envelope.currentBalance)),

          ),

        ),

      if (summary.activeLoansCount > 0 &&

          summary.loansRemainingTotal.isPositive)

        _AlertTile(

          icon: Icons.request_page_rounded,

          message: DashboardStrings.activeLoansSummaryAlert(

            summary.activeLoansCount,

            AppFormatters.money(summary.loansRemainingTotal),

          ),

        ),

    ];

    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        const Text(

          DashboardStrings.alertsSectionTitle,

          style: AppTypography.headlineSmall,

        ),

        const SizedBox(height: AppDimensions.itemSpacing),

        if (alerts.isEmpty)

          const AppEmptyView(

            message: DashboardStrings.noAlerts,

            icon: Icons.verified_outlined,

            isCompact: true,

          )

        else

          ...alerts,

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

    return Padding(

      padding: const EdgeInsets.only(bottom: AppDimensions.itemSpacing),

      child: AppCard(

        backgroundColor: AppColors.warningLight,

        borderColor: AppColors.warningLight,

        child: Row(

          children: [

            const Icon(

              Icons.warning_amber_rounded,

              color: AppColors.warning,

              size: AppDimensions.iconMedium,

            ),

            const SizedBox(width: AppDimensions.spacing12),

            Expanded(

              child: Text(

                message,

                style: AppTypography.bodyMedium,

              ),

            ),

          ],

        ),

      ),

    );

  }

}
