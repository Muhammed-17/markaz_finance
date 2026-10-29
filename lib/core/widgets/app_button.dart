import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_durations.dart';

/// أنماط زر التطبيق الموحد.
enum AppButtonVariant { primary, secondary, danger, text }

/// زر التطبيق الموحد — يستخدم AppDimensions وAppColors حصريًا.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.height = AppDimensions.buttonHeight,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double height;

  bool get _isDisabled => onPressed == null || isLoading;

  Color get _background {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.secondary;
      case AppButtonVariant.danger:
        return AppColors.error;
      case AppButtonVariant.text:
        return Colors.transparent;
    }
  }

  Color get _foreground {
    switch (variant) {
      case AppButtonVariant.text:
        return AppColors.primary;
      default:
        return AppColors.textOnPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = AnimatedSwitcher(
      duration: AppDurations.fast,
      child: isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: AppDimensions.iconMedium,
              height: AppDimensions.iconMedium,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_foreground),
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppDimensions.iconMedium - 2),
                  const SizedBox(width: AppDimensions.spacing8),
                ],
                if (isFullWidth)
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isDisabled && variant != AppButtonVariant.text
                            ? AppColors.surface
                            : _foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _isDisabled && variant != AppButtonVariant.text
                          ? AppColors.surface
                          : _foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
    );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: Material(
        color: _isDisabled && variant != AppButtonVariant.text
            ? AppColors.disabled
            : _background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: InkWell(
          onTap: _isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing20,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
