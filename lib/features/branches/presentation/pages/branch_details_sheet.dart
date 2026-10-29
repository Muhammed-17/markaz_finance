
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/branch_entity.dart';

/// BottomSheet تفاصيل الفرع — عرض معلوماته كاملة.
class BranchDetailsSheet extends StatelessWidget {
  const BranchDetailsSheet({
    required this.branch,
    this.centerName,
    super.key,
  });

  final BranchEntity branch;

  /// اسم المركز التابع له الفرع (إن وُجد في القائمة المرجعية).
  final String? centerName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.cardPaddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'تفاصيل الفرع',
                    style: AppTypography.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      size: AppDimensions.iconMedium),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing16),
            AppCard(
              backgroundColor: AppColors.surfaceAlt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppInfoRow(label: AppStrings.name, value: branch.name),
                  AppInfoRow(
                    label: AppStrings.center,
                    value: AppFormatters.orDash(centerName),
                  ),
                  AppInfoRow(
                    label: 'الموقع',
                    value: AppFormatters.orDash(branch.location),
                  ),
                  AppInfoRow(
                    label: 'تاريخ الإنشاء',
                    value: AppFormatters.dateTime(branch.createdAt),
                  ),
                  AppInfoRow(
                    label: 'آخر تحديث',
                    value: AppFormatters.dateTime(branch.updatedAt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
