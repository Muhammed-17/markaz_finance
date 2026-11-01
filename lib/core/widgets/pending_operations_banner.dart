import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/di/injection.dart';
import '../../app/router/route_guards.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_dimensions.dart';
import '../data/models/pending_operation_model.dart';
import '../services/pending_operations_service.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'app_button.dart';

/// شريط علوي يُعرض عند وجود عمليات مالية معلقة بانتظار المزامنة.
class PendingOperationsBanner extends StatelessWidget {
  const PendingOperationsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = sl<PendingOperationsService>();

    return StreamBuilder<List<PendingOperationModel>>(
      stream: service.operationsStream,
      initialData: service.ownOperations,
      builder: (context, snapshot) {
        final operations = snapshot.data ?? const [];
        if (operations.isEmpty) return const SizedBox.shrink();

        final hasFailed = operations
            .any((op) => op.status == PendingOperationStatus.failed);
        final isSyncing = service.isSyncing ||
            operations.any((op) => op.status == PendingOperationStatus.syncing);

        final Color bg = hasFailed
            ? AppColors.errorLight
            : (isSyncing ? AppColors.infoLight : AppColors.warningLight);
        final Color textColor = hasFailed
            ? AppColors.error
            : (isSyncing ? AppColors.info : AppColors.warning);
        final IconData icon = hasFailed
            ? Icons.error_outline_rounded
            : (isSyncing
                ? Icons.sync_rounded
                : Icons.cloud_queue_rounded);

        final String text;
        if (isSyncing) {
          text = 'جارٍ مزامنة (${operations.length}) عمليات معلقة مع الخادم...';
        } else if (hasFailed) {
          text = 'تعذر اعتماد بعض العمليات المعلقة لوجود تعارض في الرصيد';
        } else {
          text = 'لديك (${operations.length}) عمليات معلقة بانتظار عودة الاتصال';
        }

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingMobile,
            vertical: AppDimensions.spacing8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing12,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: textColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: AppDimensions.iconMedium),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.bodySmall.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              TextButton(
                onPressed: () => _showOperationsSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing12,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('عرض التفاصيل'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOperationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLarge),
        ),
      ),
      builder: (_) => const _PendingOperationsSheet(),
    );
  }
}

class _PendingOperationsSheet extends StatelessWidget {
  const _PendingOperationsSheet();

  @override
  Widget build(BuildContext context) {
    final service = sl<PendingOperationsService>();

    return StreamBuilder<List<PendingOperationModel>>(
      stream: service.operationsStream,
      initialData: service.ownOperations,
      builder: (context, snapshot) {
        final operations = snapshot.data ?? const [];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: AppDimensions.bottomSheetHandleWidth,
                    height: AppDimensions.bottomSheetHandleHeight,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing16),
                const Text(
                  'العمليات المالية المعلقة (Offline Drafts)',
                  style: AppTypography.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacing8),
                const Text(
                  'هذه العمليات محفوظة كمسودات على هذا الجهاز فقط، ولن تؤثر على الأرصدة أو السجلات حتى تُعتمد بنجاح في الخادم.',
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacing16),
                if (operations.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(AppDimensions.spacing24),
                    child: Center(
                      child: Text(
                        'لا توجد أي عمليات معلقة حاليًا',
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  ),
                ] else ...[
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: operations.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimensions.spacing8),
                      itemBuilder: (context, index) {
                        final op = operations[index];
                        return _OperationTile(operation: op);
                      },
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing16),
                  AppButton(
                    label: service.isSyncing
                        ? 'جارٍ المزامنة...'
                        : 'مزامنة كل العمليات المعلقة الآن',
                    icon: Icons.sync_rounded,
                    isLoading: service.isSyncing,
                    onPressed: service.isSyncing
                        ? null
                        : () => service.syncAll(includeFailed: true),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.operation});

  final PendingOperationModel operation;

  @override
  Widget build(BuildContext context) {
    final service = sl<PendingOperationsService>();

    final (statusLabel, statusColor) = switch (operation.status) {
      PendingOperationStatus.pending => ('بانتظار الاتصال', AppColors.warning),
      PendingOperationStatus.syncing => ('جارٍ المزامنة...', AppColors.info),
      PendingOperationStatus.failed => ('تعذر الاعتماد', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  operation.title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing8,
                  vertical: AppDimensions.spacing4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: Text(
                  statusLabel,
                  style: AppTypography.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.error),
                tooltip: 'إلغاء وحذف المسودة',
                onPressed: () => service.deleteOperation(operation.id),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing4),
          Text(
            'وقت الحفظ: ${AppFormatters.date(operation.createdAt)}',
            style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary),
          ),
          if (operation.status == PendingOperationStatus.failed &&
              operation.type == AppFunctions.repayLoan &&
              operation.payload['loanId'] is String) ...[
            const SizedBox(height: AppDimensions.spacing4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () {
                  final router = GoRouter.of(context);
                  final loanId = operation.payload['loanId'] as String;
                  Navigator.of(context).pop();
                  router.push('${RoutePaths.loans}/$loanId');
                },
                child: const Text('فتح السلفة للتعديل وإعادة الإرسال'),
              ),
            ),
          ],
          if (operation.failureReason != null) ...[
            const SizedBox(height: AppDimensions.spacing8),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacing8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: AppDimensions.spacing8),
                  Expanded(
                    child: Text(
                      'السبب: ${operation.failureReason}',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
