import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
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

/// شريط فلاتر التقرير: الفترة، المركز، النوع، التصنيف، الظرف + زر التوليد.
class ReportFiltersBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final categories = filter.type == null
        ? const <String>[]
        : filter.type == AppTransactionTypes.income
            ? AppIncomeCategories.all
            : AppExpenseCategories.all;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الفترة: أزرار سريعة
          const Text(ReportsStrings.periodLabel,
              style: AppTypography.titleMedium),
          const SizedBox(height: AppDimensions.spacing8),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              _PeriodChip(
                label: ReportsStrings.periodThisMonth,
                selected: selectedPeriod == ReportPeriod.thisMonth,
                onTap: () => onPeriodSelected(ReportPeriod.thisMonth),
              ),
              _PeriodChip(
                label: ReportsStrings.periodLastMonth,
                selected: selectedPeriod == ReportPeriod.lastMonth,
                onTap: () => onPeriodSelected(ReportPeriod.lastMonth),
              ),
              _PeriodChip(
                label: ReportsStrings.periodThisYear,
                selected: selectedPeriod == ReportPeriod.thisYear,
                onTap: () => onPeriodSelected(ReportPeriod.thisYear),
              ),
              _PeriodChip(
                label: ReportsStrings.periodAll,
                selected: selectedPeriod == ReportPeriod.all,
                onTap: () => onPeriodSelected(ReportPeriod.all),
              ),
              _PeriodChip(
                label: ReportsStrings.periodCustom,
                selected: selectedPeriod == ReportPeriod.custom,
                onTap: () => onPeriodSelected(ReportPeriod.custom),
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
                    onPicked: (d) => onCustomDatesPicked(d, filter.to),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: _CustomDateField(
                    label: ReportsStrings.customToDate,
                    value: filter.to,
                    firstDate: filter.from,
                    onPicked: (d) => onCustomDatesPicked(filter.from, d),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppDimensions.spacing16),
          Wrap(
            spacing: AppDimensions.spacing12,
            runSpacing: AppDimensions.spacing12,
            children: [
              // المركز
              SizedBox(
                width: 200,
                child: AppDropdownField<String>(
                  label: AppStrings.center,
                  items: centers
                      .map((c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(c.name),
                          ))
                      .toList(),
                  value: filter.centerId,
                  hint: AppStrings.all,
                  onChanged: (v) => onFilterChanged(
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
              ),
              // النوع
              SizedBox(
                width: 170,
                child: AppDropdownField<String>(
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
                  onChanged: (v) => onFilterChanged(
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
              ),
              // التصنيف (يُحدَّث حسب النوع)
              SizedBox(
                width: 220,
                child: CategoryField(
                  label: AppStrings.category,
                  categories: categories,
                  value: (filter.category != null &&
                          categories.contains(filter.category))
                      ? filter.category
                      : null,
                  isRequired: false,
                  onChanged: (v) => onFilterChanged(
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
              ),
              // الظرف
              SizedBox(
                width: 220,
                child: AppDropdownField<String>(
                  label: AppStrings.relatedEnvelope,
                  items: envelopes
                      .map((e) => DropdownMenuItem<String>(
                            value: e.id,
                            child: Text(e.name),
                          ))
                      .toList(),
                  value: filter.envelopeId,
                  hint: AppStrings.all,
                  onChanged: (v) => onFilterChanged(
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
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              label: ReportsStrings.generateReport,
              icon: Icons.assessment_outlined,
              isFullWidth: false,
              isLoading: isGenerating,
              onPressed: isGenerating ? null : onGenerate,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryLight,
      labelStyle: AppTypography.labelMedium.copyWith(
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        side:
            BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing4,
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
