import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_durations.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// هيكل صفحة قابل للتمرير بعرض محتوى أقصى وحشوة متجاوبة،
/// مع سحب للتحديث اختياريًا.
class AppPageScroll extends StatelessWidget {
  const AppPageScroll({
    required this.children,
    this.maxWidth = AppDimensions.maxContentWidth,
    this.onRefresh,
    super.key,
  });

  final List<Widget> children;
  final double maxWidth;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = AppTypography.pagePaddingForWidth(width);

    final body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
          padding: EdgeInsets.all(padding),
          children: children,
        ),
      ),
    );

    if (onRefresh == null) return body;
    return RefreshIndicator(onRefresh: onRefresh!, child: body);
  }
}

/// ترويسة صفحة موحدة: عنوان + سطر فرعي + إجراءات.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.headlineLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppDimensions.spacing2),
                Text(subtitle!, style: AppTypography.bodySmall),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// عنوان قسم موحد (عنوان + سطر فرعي + عنصر جانبي اختياري).
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.headlineSmall),
              if (subtitle != null)
                Text(subtitle!, style: AppTypography.bodySmall),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// شارة أيقونة مدورة بخلفية لونية خفيفة.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    required this.icon,
    required this.color,
    required this.background,
    this.size = AppDimensions.iconBadgeSize,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Icon(icon, color: color, size: AppDimensions.iconMedium),
    );
  }
}

/// بطاقة بارزة بتدرج أخضر (الرصيد الرئيسي في الصفحة).
class AppHeroCard extends StatelessWidget {
  const AppHeroCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.cardPaddingLarge),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [AppColors.heroGradientStart, AppColors.heroGradientEnd],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -AppDimensions.spacing48,
              end: -AppDimensions.spacing40,
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onHeroSurface,
                ),
              ),
            ),
            PositionedDirectional(
              bottom: -AppDimensions.spacing48,
              start: -AppDimensions.spacing32,
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.onHeroSurface,
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// شريحة صغيرة شفافة داخل البطاقة البارزة.
class AppHeroPill extends StatelessWidget {
  const AppHeroPill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing4,
      ),
      decoration: BoxDecoration(
        color: AppColors.onHeroSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

/// مؤشر صغير داخل البطاقة البارزة (أيقونة + عنوان + قيمة).
class AppHeroMetric extends StatelessWidget {
  const AppHeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.onHeroSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textOnPrimary,
            size: AppDimensions.iconMedium,
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.onHeroMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شريحة اختيار دائرية (فترات/فلاتر سريعة).
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing8,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusExtraLarge),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppDimensions.iconSmall + 2, color: foreground),
                const SizedBox(width: AppDimensions.spacing4),
              ],
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة مؤشر عصرية (أيقونة + عنوان + قيمة + سطر فرعي).
class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
    this.subtitle,
    this.valueColor,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
  final String? subtitle;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      onTap: onTap,
      child: Row(
        children: [
          AppIconBadge(icon: icon, color: color, background: background),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.spacing2),
                Text(
                  value,
                  style: AppTypography.headlineSmall.copyWith(
                    color: valueColor ?? AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شبكة متجاوبة: عدد الأعمدة يُحسب من الحد الأدنى لعرض العنصر.
class AppResponsiveGrid extends StatelessWidget {
  const AppResponsiveGrid({
    required this.children,
    this.minItemWidth = AppDimensions.cardMinWidth,
    this.spacing = AppDimensions.itemSpacing,
    this.maxColumns = 4,
    super.key,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        var columns = ((available + spacing) / (minItemWidth + spacing)).floor();
        columns = math.max(1, math.min(columns, math.min(maxColumns, children.length)));
        final itemWidth = (available - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
