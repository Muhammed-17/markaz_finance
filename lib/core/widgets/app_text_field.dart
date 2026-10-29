import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_typography.dart';

typedef AppFormFieldValidator = String? Function(String? value);

/// حقل إدخال التطبيق الموحد مع تسمية ورسائل تحقق عربية.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.validator,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
    this.autofillHints,
    this.autovalidateMode,
    this.helperText,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final AppFormFieldValidator? validator;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final AutovalidateMode? autovalidateMode;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.titleMedium),
        const SizedBox(height: AppDimensions.spacing8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: AppDimensions.iconMedium)
                : null,
            suffixIcon: suffixIcon,
            helperText: helperText,
            counterText: '',
          ),
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: maxLines,
          minLines: maxLines > 1 ? 3 : null,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          autofillHints: autofillHints,
          autovalidateMode: autovalidateMode,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// حقل قائمة منسدلة موحد.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
    this.hint,
    this.enabled = true,
    this.isExpanded = true,
    super.key,
  });

  final String label;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final AppFormFieldValidator? validator;
  final String? hint;
  final bool enabled;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.titleMedium),
        const SizedBox(height: AppDimensions.spacing8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator as FormFieldValidator<T>?,
          hint: hint != null ? Text(hint!) : null,
          isExpanded: isExpanded,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          icon: const Icon(Icons.expand_more_rounded),
          dropdownColor: AppColors.surface,
          decoration: const InputDecoration(),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
