import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/center_entity.dart';

/// BottomSheet تفاصيل المركز — عرض معلوماته كاملة.
class CenterDetailsSheet extends StatelessWidget {
  const CenterDetailsSheet({required this.center, super.key});

  final CenterEntity center;

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
                    'تفاصيل المركز',
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
                  AppInfoRow(label: AppStrings.name, value: center.name),
                  AppInfoRow(
                    label: AppStrings.description,
                    value: AppFormatters.orDash(center.description),
                  ),
                  AppInfoRow(
                    label: 'تاريخ الإنشاء',
                    value: AppFormatters.dateTime(center.createdAt),
                  ),
                  AppInfoRow(
                    label: 'آخر تحديث',
                    value: AppFormatters.dateTime(center.updatedAt),
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
