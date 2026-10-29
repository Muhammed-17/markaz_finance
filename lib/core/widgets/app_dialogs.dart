import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_text_field.dart';

/// حوار تأكيد موحد.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'إلغاء',
  bool isDanger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.overlayBarrier,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        AppButton(
          label: confirmLabel,
          isFullWidth: false,
          variant: isDanger ? AppButtonVariant.danger : AppButtonVariant.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// حوار إدخال سبب إلزامي (يُستخدم عند إلغاء حركة مالية مثلًا).
/// يرجع السبب النصي أو null إذا تم الإلغاء.
Future<String?> showAppReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'إلغاء الحركة',
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String>(
    context: context,
    barrierColor: AppColors.overlayBarrier,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: AppTypography.bodyMedium),
              const SizedBox(height: AppDimensions.spacing16),
              AppTextField(
                label: 'سبب الإلغاء',
                controller: controller,
                maxLines: 3,
                maxLength: 500,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'سبب الإلغاء مطلوب';
                  if (v.length < 3) {
                    return 'اكتب سببًا واضحًا (3 أحرف على الأقل)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('رجوع'),
          ),
          AppButton(
            label: confirmLabel,
            isFullWidth: false,
            variant: AppButtonVariant.danger,
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
          ),
        ],
      ),
    ),
  );
  return result;
}

/// شريط سفلي/حوار موحد لعرض تنبيه نجاح أو خطأ.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? AppColors.errorLight : AppColors.successLight,
              size: AppDimensions.iconMedium,
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor:
            isError ? AppColors.error : AppColors.textPrimary,
        duration: const Duration(seconds: 4),
      ),
    );
}
