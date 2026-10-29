import '../constants/app_constants.dart';

/// مدققات مدخلات النماذج — رسائل عربية جاهزة للعرض.
abstract final class AppValidators {
  static final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  static final RegExp _forMonthRegex = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');
  static final RegExp _amountRegex = RegExp(r'^\d{1,12}(\.\d{1,2})?$');

  static String? required(String? value, {String fieldName = 'هذا الحقل'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName مطلوب';
    }
    return null;
  }

  static String? name(String? value, {String fieldName = 'الاسم'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$fieldName مطلوب';
    if (v.length < 3) return '$fieldName قصير جدًا (3 أحرف على الأقل)';
    if (v.length > 200) return '$fieldName طويل جدًا (200 حرف كحد أقصى)';
    return null;
  }

  static String? description(String? value,
      {bool isRequired = false, String fieldName = 'الوصف'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return isRequired ? '$fieldName مطلوب' : null;
    if (v.length > 500) return '$fieldName طويل جدًا (500 حرف كحد أقصى)';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'البريد الإلكتروني مطلوب';
    if (!_emailRegex.hasMatch(v)) return 'صيغة البريد الإلكتروني غير صحيحة';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'كلمة المرور مطلوبة';
    if (v.length < 8) return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
    if (v.length > 128) return 'كلمة المرور طويلة جدًا';
    return null;
  }

  /// مدقق المبلغ النصي: رقم موجب بمنزلتين عشريتين كحد أقصى، وغير صفري.
  static String? amount(String? value,
      {String fieldName = 'المبلغ', bool allowZero = false}) {
    final v = value?.trim().replaceAll(',', '') ?? '';
    if (v.isEmpty) return '$fieldName مطلوب';
    if (!_amountRegex.hasMatch(v)) {
      return 'أدخل مبلغًا صحيحًا بحد أقصى منزلتين عشريتين';
    }
    final parsed = double.tryParse(v);
    if (parsed == null) return 'أدخل مبلغًا صحيحًا';
    if (parsed > 1000000000) return 'المبلغ يتجاوز الحد الأقصى المسموح';
    if (!allowZero && parsed <= 0) return 'يجب أن يكون $fieldName أكبر من صفر';
    return null;
  }

  /// الشهر المالي بصيغة YYYY-MM.
  static String? forMonth(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'الشهر المالي مطلوب';
    if (!_forMonthRegex.hasMatch(v)) return 'صيغة الشهر غير صحيحة (مثال: 2025-03)';
    return null;
  }

  static String? notes(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > 1000) return 'الملاحظات طويلة جدًا (1000 حرف كحد أقصى)';
    return null;
  }

  /// سبب إلغاء إلزامي بحد أدنى.
  static String? cancelReason(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'سبب الإلغاء مطلوب';
    if (v.length < 3) return 'اكتب سببًا واضحًا للإلغاء (3 أحرف على الأقل)';
    if (v.length > 500) return 'سبب الإلغاء طويل جدًا (500 حرف كحد أقصى)';
    return null;
  }

  /// التحقق من أن قيمة نصية ضمن قائمة القيم المسموحة.
  static bool isAllowedValue(String value, List<String> allowed) =>
      allowed.contains(value);

  /// التحقق من تصنيف حركة مقابل نوعها.
  static bool isValidCategory(String type, String category) {
    if (type == AppTransactionTypes.income) {
      return AppIncomeCategories.all.contains(category);
    }
    if (type == AppTransactionTypes.expense) {
      return AppExpenseCategories.all.contains(category);
    }
    return false;
  }
}
