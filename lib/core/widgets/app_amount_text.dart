import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';

/// نص مبلغ موحد ملوّن دلاليًا (إيراد أخضر / مصروف أحمر).
class AppAmountText extends StatelessWidget {
  const AppAmountText({
    required this.amount,
    required this.isIncome,
    this.showSign = true,
    this.style,
    super.key,
  });

  final num amount;
  final bool isIncome;
  final bool showSign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppColors.income : AppColors.expense;
    final text = AppFormatters.amountSigned(
      isIncome ? amount.abs() : -amount.abs(),
      showSign: showSign,
    );
    return Text(
      text,
      style: (style ?? AppTypography.titleMedium).copyWith(color: color),
      textAlign: TextAlign.start,
    );
  }
}

/// نص مبلغ محايد (للأرصدة والإجماليات).
class AppNeutralAmountText extends StatelessWidget {
  const AppNeutralAmountText({
    required this.amount,
    this.style,
    this.color,
    super.key,
  });

  final num amount;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppFormatters.amount(amount),
      style: (style ?? AppTypography.titleMedium).copyWith(color: color),
    );
  }
}
