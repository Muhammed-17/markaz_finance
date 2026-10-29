import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// عرض خطأ موحد مع إمكانية إعادة المحاولة.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.message,
    this.onRetry,
    this.isCompact = false,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: isCompact ? AppDimensions.iconLarge : AppDimensions.spacing48,
          color: AppColors.error,
        ),
        const SizedBox(height: AppDimensions.spacing16),
        Text(
          message,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppDimensions.spacing20),
          AppButton(
            label: 'إعادة المحاولة',
            onPressed: onRetry,
            isFullWidth: false,
            icon: Icons.refresh_rounded,
          ),
        ],
      ],
    );

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: content,
      );
    }
    return Center(child: Padding(padding: const EdgeInsets.all(AppDimensions.spacing32), child: content));
  }
}

/// عرض فراغ موحد (قائمة بدون عناصر).
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.isCompact = false,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData icon;
  final bool isCompact;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isCompact ? AppDimensions.iconLarge : AppDimensions.spacing48,
          color: AppColors.disabled,
        ),
        const SizedBox(height: AppDimensions.spacing16),
        Text(
          message,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppDimensions.spacing20),
          AppButton(
            label: actionLabel!,
            onPressed: onAction,
            isFullWidth: false,
            icon: Icons.add_rounded,
          ),
        ],
      ],
    );

    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: content,
      );
    }
    return Center(child: Padding(padding: const EdgeInsets.all(AppDimensions.spacing32), child: content));
  }
}
