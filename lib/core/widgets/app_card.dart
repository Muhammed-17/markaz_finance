import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_typography.dart';

/// بطاقة التطبيق الموحدة.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppDimensions.cardPadding),
    this.margin = EdgeInsets.zero,
    this.borderColor,
    this.backgroundColor,
    this.elevated = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final Color? backgroundColor;

  /// ظل ناعم خفيف (التصميم الحديث للصفحات الرئيسية).
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// ترويسة قسم موحدة (عنوان + إجراء اختياري).
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: AppTypography.headlineSmall),
        ),
        if (actionLabel != null && onAction != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_circle_outline_rounded,
                size: AppDimensions.iconMedium),
            label: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// صف معلومة موحد (تسمية: قيمة) — يُستخدم في التفاصيل والبطاقات.
class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
    super.key,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTypography.titleSmall),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  AppTypography.bodyMedium.copyWith(color: valueColor),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}

/// شريحة (Chip) موحدة للحالة.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    required this.label,
    required this.color,
    required this.backgroundColor,
    super.key,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(color: color),
      ),
    );
  }
}
