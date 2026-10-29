import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/categories_service.dart';
import '../../../../core/widgets/app_text_field.dart';

/// دالة تحويل قيمة تصنيف نصية إلى تسمية عربية مقروءة.
///
/// تُستخدم في شاشات التقارير، الأظرف، ولوحة التحكم لعرض التصنيف بشكل مناسب.
String categoryLabel(String category) {
  final label = switch (category) {
    // ── الإيرادات ──────────────────────────────────────────────────────────
    AppIncomeCategories.studentSubscription => 'اشتراكات الطلاب',
    AppIncomeCategories.donation            => 'تبرعات',
    AppIncomeCategories.loanRepayment       => 'سداد سلفة',
    AppIncomeCategories.otherIncome         => 'إيرادات أخرى',
    AppIncomeCategories.openingBalance      => 'رصيد افتتاحي',
    // ── المصروفات ─────────────────────────────────────────────────────────
    AppExpenseCategories.employeeLoan         => 'سلفة موظف',
    AppExpenseCategories.salaries             => 'رواتب',
    AppExpenseCategories.rent                 => 'إيجار',
    AppExpenseCategories.utilities            => 'مرافق',
    AppExpenseCategories.maintenance          => 'صيانة',
    AppExpenseCategories.supplies             => 'مستلزمات',
    AppExpenseCategories.quranCopiesPurchase  => 'شراء مصاحف',
    AppExpenseCategories.fansPurchase         => 'شراء مراوح',
    AppExpenseCategories.otherExpense         => 'مصروفات أخرى',
    // ── غير معرّف في الثوابت ──────────────────────────────────────────────
    _                                         => null,
  };
  if (label != null) return label;
  try {
    if (GetIt.instance.isRegistered<CategoriesService>()) {
      return GetIt.instance<CategoriesService>().getLabel(category);
    }
  } catch (_) {}
  return category;
}

/// حقل اختيار التصنيف المالي (إيرادات أو مصروفات) بناءً على قائمة ديناميكية.
///
/// يُستخدم في نماذج الحركات المالية وشريط فلاتر التقارير.
/// عند [isRequired] = false تظهر خيار "الكل" ضمنيًا (من خلال hint).
class CategoryField extends StatelessWidget {
  const CategoryField({
    required this.label,
    required this.categories,
    required this.value,
    required this.onChanged,
    this.isRequired = true,
    this.hint,
    super.key,
  });

  final String label;

  /// قائمة التصنيفات المتاحة (AppIncomeCategories.all أو AppExpenseCategories.all).
  final List<String> categories;

  /// القيمة المختارة حاليًا (null تعني "الكل" أو "غير محدد").
  final String? value;

  final ValueChanged<String?> onChanged;

  /// هل الحقل مطلوب (يُظهر علامة * ويمنع الإرسال إذا فارغ).
  final bool isRequired;

  /// نص التلميح (الافتراضي يعتمد على [isRequired]).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return AppDropdownField<String>(
      label: label,
      hint: hint ?? (isRequired ? null : 'الكل'),
      value: (value != null && categories.contains(value)) ? value : null,
      items: categories
          .map(
            (cat) => DropdownMenuItem<String>(
              value: cat,
              child: Text(
                categoryLabel(cat),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
