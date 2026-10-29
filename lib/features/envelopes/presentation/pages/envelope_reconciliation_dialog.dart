import 'package:flutter/material.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_amount_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/envelope_reconciliation_entity.dart';
import '../../domain/usecases/envelopes_usecases.dart';

/// نافذة الفحص والمطابقة المحاسبية الدورية للأظرف المالية (الخيار ج).
/// تقارن الرصيد المسجل لكل ظرف بمجموع حركات envelopeTransactions في Firestore.
class EnvelopeReconciliationDialog extends StatefulWidget {
  const EnvelopeReconciliationDialog({super.key});

  @override
  State<EnvelopeReconciliationDialog> createState() =>
      _EnvelopeReconciliationDialogState();
}

class _EnvelopeReconciliationDialogState
    extends State<EnvelopeReconciliationDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  EnvelopeReconciliationResult? _result;

  @override
  void initState() {
    super.initState();
    _runReconciliation();
  }

  Future<void> _runReconciliation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final useCase = sl<ReconcileEnvelopes>();
    final failureOrResult = await useCase();

    if (!mounted) return;

    failureOrResult.fold(
      (failure) => setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      }),
      (result) => setState(() {
        _isLoading = false;
        _result = result;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const Divider(height: AppDimensions.spacing24),
              Expanded(child: _buildBody(context)),
              const SizedBox(height: AppDimensions.spacing16),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          child: const Icon(
            Icons.fact_check_outlined,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التسوية والمطابقة المحاسبية للأظرف',
                style: AppTypography.headlineSmall,
              ),
              SizedBox(height: 2),
              Text(
                'فحص دوري يقارن الرصيد الحالي للظرف بمجموع حركاته التاريخية',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'إغلاق',
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: AppLoadingView(message: 'جاري فحص ومطابقة جميع حركات الأظرف...'),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: AppDimensions.spacing12),
            Text(_errorMessage!,
                style: AppTypography.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.spacing16),
            AppButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh_rounded,
              isFullWidth: false,
              onPressed: _runReconciliation,
            ),
          ],
        ),
      );
    }

    final res = _result;
    if (res == null || res.items.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد أظرف مالية مسجلة بعد.',
          style: AppTypography.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryBanners(res),
        const SizedBox(height: AppDimensions.spacing16),
        Text(
          'تفاصيل الأظرف (${res.totalEnvelopes}):',
          style: AppTypography.bodySmall
              .copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        Expanded(
          child: ListView.separated(
            itemCount: res.items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppDimensions.spacing8),
            itemBuilder: (context, index) {
              final item = res.items[index];
              return _buildEnvelopeItemCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBanners(EnvelopeReconciliationResult res) {
    final isAllGood = !res.hasDiscrepancy;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing12),
          decoration: BoxDecoration(
            color: isAllGood
                ? AppColors.success.withValues(alpha: 0.08)
                : AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isAllGood
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAllGood
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: isAllGood ? AppColors.success : AppColors.error,
                size: 28,
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Text(
                  isAllGood
                      ? 'جميع أرصدة الأظرف مطابقة تماماً لسجل الحركات بدون أي انحراف (100% تطابق).'
                      : 'تنبيه: تم رصد انحراف في (${res.discrepancyCount}) ظرف مالي! راجع الفروقات أدناه.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: isAllGood ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'إجمالي الرصيد المسجل',
                amount: res.totalCurrentBalance,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Expanded(
              child: _buildMetricTile(
                title: 'إجمالي مجموع الحركات',
                amount: res.totalCalculatedBalance,
                icon: Icons.history_edu_outlined,
              ),
            ),
            const SizedBox(width: AppDimensions.spacing8),
            Expanded(
              child: _buildMetricTile(
                title: 'حالة المطابقة',
                textValue: '${res.matchedCount} / ${res.totalEnvelopes}',
                subText: isAllGood ? 'مطابقة تامة' : 'يوجد انحراف',
                icon: Icons.verified_outlined,
                color: isAllGood ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    double? amount,
    String? textValue,
    String? subText,
    required IconData icon,
    Color? color,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (amount != null)
            AppNeutralAmountText(
              amount: amount,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? AppColors.textPrimary,
              ),
            )
          else if (textValue != null)
            Text(
              textValue,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          if (subText != null)
            Text(
              subText,
              style: AppTypography.labelSmall.copyWith(
                color: color ?? AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnvelopeItemCard(EnvelopeReconciliationItem item) {
    final isMatched = item.isMatched;

    return AppCard(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      child: Row(
        children: [
          Icon(
            isMatched ? Icons.check_circle : Icons.error,
            color: isMatched ? AppColors.success : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.envelopeName,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${item.transactionCount} حركة مسجلة',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('الرصيد الحالي:', style: AppTypography.labelSmall),
                AppNeutralAmountText(
                  amount: item.currentBalance,
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('المحسوب:', style: AppTypography.labelSmall),
                AppNeutralAmountText(
                  amount: item.calculatedBalance,
                  style: AppTypography.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMatched
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            child: Text(
              isMatched
                  ? 'مطابق'
                  : 'فارق: ${AppFormatters.amount(item.discrepancy)}',
              style: AppTypography.labelSmall.copyWith(
                color: isMatched ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_result != null)
          Text(
            'آخر فحص: ${AppFormatters.dateTime(_result!.reconciledAt)}',
            style: AppTypography.bodySmall,
          )
        else
          const SizedBox.shrink(),
        Row(
          children: [
            AppButton(
              label: 'إعادة الفحص',
              icon: Icons.refresh_rounded,
              isFullWidth: false,
              variant: AppButtonVariant.secondary,
              onPressed: _isLoading ? null : _runReconciliation,
            ),
            const SizedBox(width: AppDimensions.spacing8),
            AppButton(
              label: 'تم',
              isFullWidth: false,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}
