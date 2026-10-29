import 'package:flutter/material.dart';

/// الهوية اللونية المركزية للتطبيق.
/// ممنوع استخدام أي لون عشوائي داخل الودجات — كل الألوان من هنا فقط.
abstract final class AppColors {
  // Primary (أخضر إسلامي معاصر)
  static const Color primary = Color(0xFF176B5B);
  static const Color primaryDark = Color(0xFF104C41);
  static const Color primaryLight = Color(0xFFE4F2EE);

  // Secondary (ذهبي)
  static const Color secondary = Color(0xFFC5A15A);
  static const Color secondaryLight = Color(0xFFF5EEDC);

  // Surfaces
  static const Color background = Color(0xFFF7F9F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0F4F2);

  // Text
  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textSecondary = Color(0xFF65727D);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE1E7E5);

  // Semantic
  static const Color success = Color(0xFF21845A);
  static const Color successLight = Color(0xFFE3F3EA);
  static const Color warning = Color(0xFFD99024);
  static const Color warningLight = Color(0xFFFDF3E2);
  static const Color error = Color(0xFFB83A3A);
  static const Color errorLight = Color(0xFFFBEAEA);
  static const Color info = Color(0xFF3478B8);
  static const Color infoLight = Color(0xFFE8F1FA);

  // Financial
  static const Color income = Color(0xFF21845A);
  static const Color incomeLight = Color(0xFFE3F3EA);
  static const Color expense = Color(0xFFB83A3A);
  static const Color expenseLight = Color(0xFFFBEAEA);

  // States
  static const Color disabled = Color(0xFFB7C0C5);
  static const Color shimmer = Color(0xFFE8EEEC);
  static const Color overlayBarrier = Color(0x66000000);
}
