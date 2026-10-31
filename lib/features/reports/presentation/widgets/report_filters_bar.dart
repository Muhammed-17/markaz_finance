import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_page_widgets.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../transactions/presentation/widgets/month_field.dart'
    show CategoryField;
import '../../domain/entities/report_filter.dart';
import '../../reports_strings.dart';

/// خيارات الفترة السريعة في شريط فلاتر التقرير.
enum ReportPeriod { thisMonth, lastMonth, thisYear, all, custom }

/// حساب حدود الفترة المختارة (شاملة الطرفين).
abstract final class ReportPeriodBounds {
  static (DateTime?, DateTime?) resolve(
    ReportPeriod period, {
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    final now = DateTime.now();
    switch (period) {
      case ReportPeriod.thisMonth:
        return AppDateTimeUtils.monthRange(AppDateTimeUtils.currentMonthKey);
      case ReportPeriod.lastMonth:
        final previous = AppDateTimeUtils.addMonthsToKey(
            AppDateTimeUtils.currentMonthKey, -1);
        return AppDateTimeUtils.monthRange(previous);
      case ReportPeriod.thisYear:
        return (
          AppDateTimeUtils.startOfYear(now),
          AppDateTimeUtils.endOfYear(now)
        );
      case ReportPeriod.all:
        return (null, null);
      case ReportPeriod.custom:
        return (customFrom, customTo);
    }
  }
}

/// شريط فلاتر التقرير: الفترة (شرائح سريعة) + فلاتر متقدمة قابلة للطي
/// (المركز، النوع، التصنيف، الظرف) + إعادة ضبط + زر التوليد.
class ReportFiltersBar extends StatefulWidget {
  const ReportFiltersBar({
    required this.filter,
    required this.centers,
    required this.envelopes,
    required this.selectedPeriod,
    required this.isGenerating,
    required this.onPeriodSelected,
    required this.onCustomDatesPicked,
    required this.onFilterChanged,
    required this.onGenerate,
    super.key,
  });

  final ReportFilter filter;
  final List<CenterRef> centers;
  final List<EnvelopeEntity> envelopes;
  final ReportPeriod selectedPeriod;
  final bool isGenerating;
  final ValueChanged<ReportPeriod> onPeriodSelected;
  final void Function(DateTime? from, DateTime? to) onCustomDatesPicked;
  final ValueChanged<ReportFilter> onFilterChanged;
  final VoidCallback onGenerate;

  @override
  State<ReportFiltersBar> createState() => _ReportFiltersBarState();
}

class _ReportFiltersBarState extends State<ReportFiltersBar> {
  late bool _advancedExpanded;

  @override
  void initState() {
    super.initState();
    _advancedExpanded = _advancedCount > 0;
  }

  int get _advancedCount {
    final f = widget.filter;
    return [f.centerId, f.type, f.category, f.envelopeId]
        .where((value) => value != null)
        .length;
  }

  void _reset() {
    final f = widget.filter;
    widget.onFilterChanged(
      ReportFilter(from: f.from, to: f.to, loanStatus: f.loanStatus),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    final selectedPeriod = widget.selectedPeriod;
    final categories = filter.type == null
        ? const <String>[]
        : filter.type == AppTransactionTypes.income
            ? AppIncomeCategories.all
            : AppExpenseCategories.all;
    final count = _advancedCount;
    final expanded = _advancedExpanded;

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.date_range_rounded,
                  color: AppColors.primary, size: AppDimensions.iconMedium),
              SizedBox(width: AppDimensions.spacing8),
              Text(ReportsStrings.periodLabel,
                  style: AppTypography.titleLarge),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              AppChoiceChip(
                label: ReportsStrings.periodThisMonth,
                selected: selectedPeriod == ReportPeriod.thisMonth,
                onTap: () => widget.onPeriodSelected(ReportPeriod.thisMonth),
              ),
              AppChoiceChip(
                label: ReportsStrings.periodLastMonth,
                selected: selectedPeriod == ReportPeriod.lastMonth,
                onTap: () => widget.onPeriodSelected(ReportPeriod.lastMonth),
              ),
              AppChoiceChip(
                label: ReportsStrings.periodThisYear,
                selected: selectedPeriod == ReportPeriod.thisYear,
                onTap: () => widget.onPeriodSelected(ReportPeriod.thisYear),
              ),
              AppChoiceChip(
                label: ReportsStrings.periodAll,
                selected: selectedPeriod == ReportPeriod.all,
                onTap: () => widget.onPeriodSelected(ReportPeriod.all),
              ),
              AppChoiceChip(
                label: ReportsStrings.periodCustom,
                icon: Icons.edit_calendar_rounded,
                selected: selectedPeriod == ReportPeriod.custom,
                onTap: () => widget.onPeriodSelected(ReportPeriod.custom),
              ),
            ],
          ),

          // التاريخان المخصصان عند اختيار فترة مخصصة
          if (selectedPeriod == ReportPeriod.custom) ...[
            const SizedBox(height: AppDimensions.spacing12),
            Row(
              children: [
                Expanded(
                  child: _CustomDateField(
                    label: ReportsStrings.customFromDate,
                    value: filter.from,
                    onPicked: (d) => widget.onCustomDatesPicked(d, filter.to),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: _CustomDateField(
                    label: ReportsStrings.customToDate,
                    value: filter.to,
                    firstDate: filter.from,
                    onPicked: (d) =>
                        widget.onCustomDatesPicked(filter.from, d),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppDimensions.spacing16),
          const Divider(),

          // رأس الفلاتر المتقدمة
          InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            onTap: () => setState(() => _advancedExpanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacing12,
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded,
                      color: AppColors.primary,
                      size: AppDimensions.iconMedium),
                  const SizedBox(width: AppDimensions.spacing8),
                  const Text('فلاتر متقدمة', style: AppTypography.titleLarge),
                  if (count > 0) ...[
                    const SizedBox(width: AppDimensions.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing8,
                        vertical: AppDimensions.spacing2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusExtraLarge),
                      ),
                      child: Text(
                        AppFormatters.integer(count),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppDurations.fast,
                    child: const Icon(Icons.expand_more_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          AnimatedSize(
            duration: AppDurations.fast,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding:
                        const EdgeInsets.only(top: AppDimensions.spacing4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppResponsiveGrid(
                          minItemWidth: 220,
                          children: [
                            // المركز
                            AppDropdownField<String>(
                              key: ValueKey('center-${filter.centerId}'),
                              label: AppStrings.center,
                              items: widget.centers
                                  .map((c) => DropdownMenuItem<String>(
                                        value: c.id,
                                        child: Text(c.name),
                                      ))
                                  .toList(),
                              value: filter.centerId,
                              hint: AppStrings.all,
                              onChanged: (v) => widget.onFilterChanged(
                                ReportFilter(
                                  from: filter.from,
                                  to: filter.to,
                                  centerId: v,
                                  type: filter.type,
                                  category: filter.category,
                                  envelopeId: filter.envelopeId,
                                  loanStatus: filter.loanStatus,
                                ),
                              ),
                            ),
                            // النوع
                            AppDropdownField<String>(
                              key: ValueKey('type-${filter.type}'),
                              label: AppStrings.type,
                              items: const [
                                DropdownMenuItem(
                                    value: AppTransactionTypes.income,
                                    child: Text(AppStrings.incomeShort)),
                                DropdownMenuItem(
                                    value: AppTransactionTypes.expense,
                                    child: Text(AppStrings.expenseShort)),
                              ],
                              value: filter.type,
                              hint: AppStrings.all,
                              onChanged: (v) => widget.onFilterChanged(
                                // تغيير النوع يصفّر التصنيف لأن قائمته تختلف.
                                ReportFilter(
                                  from: filter.from,
                                  to: filter.to,
                                  centerId: filter.centerId,
                                  type: v,
                                  category: null,
                                  envelopeId: filter.envelopeId,
                                  loanStatus: filter.loanStatus,
                                ),
                              ),
                            ),
                            // التصنيف (يُحدَّث حسب النوع)
                            CategoryField(
                              key: ValueKey(
                                  'category-${filter.type}-${filter.category}'),
                              label: AppStrings.category,
                              categories: categories,
                              value: (filter.category != null &&
                                      categories.contains(filter.category))
                                  ? filter.category
                                  : null,
                              isRequired: false,
                              onChanged: (v) => widget.onFilterChanged(
                                ReportFilter(
                                  from: filter.from,
                                  to: filter.to,
                                  centerId: filter.centerId,
                                  type: filter.type,
                                  category: v,
                                  envelopeId: filter.envelopeId,
                                  loanStatus: filter.loanStatus,
                                ),
                              ),
                            ),
                            // الظرف
                            AppDropdownField<String>(
                              key: ValueKey('envelope-${filter.envelopeId}'),
                              label: AppStrings.relatedEnvelope,
                              items: widget.envelopes
                                  .map((e) => DropdownMenuItem<String>(
                                        value: e.id,
                                        child: Text(e.name),
                                      ))
                                  .toList(),
                              value: filter.envelopeId,
                              hint: AppStrings.all,
                              onChanged: (v) => widget.onFilterChanged(
                                ReportFilter(
                                  from: filter.from,
                                  to: filter.to,
                                  centerId: filter.centerId,
                                  type: filter.type,
                                  category: filter.category,
                                  envelopeId: v,
                                  loanStatus: filter.loanStatus,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (count > 0)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: _reset,
                              icon: const Icon(Icons.restart_alt_rounded),
                              label: const Text('إعادة ضبط الفلاتر'),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: AppDimensions.spacing16),
          AppButton(
            label: ReportsStrings.generateReport,
            icon: Icons.assessment_outlined,
            isLoading: widget.isGenerating,
            onPressed: widget.isGenerating ? null : widget.onGenerate,
          ),
        ],
      ),
    );
  }
}

class _CustomDateField extends StatelessWidget {
  const _CustomDateField({
    required this.label,
    required this.value,
    required this.onPicked,
    this.firstDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: firstDate ?? DateTime(now.year - 5),
          lastDate: DateTime(now.year + 2),
          locale: const Locale('ar'),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: AppDimensions.iconMedium),
                  onPressed: () => onPicked(null),
                )
              : const Icon(Icons.calendar_today_rounded,
                  size: AppDimensions.iconMedium),
        ),
        child: Text(
          value == null ? 'اختر تاريخًا' : AppFormatters.date(value),
          style: AppTypography.bodyMedium,
        ),
      ),
    );
  }
}
