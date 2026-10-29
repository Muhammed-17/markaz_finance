import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/categories_service.dart';
import '../../../transactions/presentation/widgets/month_field.dart'
    show categoryLabel;
import '../../domain/entities/envelope_form_params.dart';
import '../../domain/repositories/envelopes_repository.dart';
import '../bloc/envelopes_bloc.dart';

/// نافذة إنشاء/تعديل ظرف مالي.
///
/// ملاحظة صارمة: fundType لا يمكن تعديله بعد الإنشاء — في وضع التعديل
/// يُعرض معطّلًا مع تنبيه نصي، ولا يُرسل إلى الخادم إطلاقًا.
class EnvelopeFormSheet extends StatefulWidget {
  const EnvelopeFormSheet({this.envelope, super.key});

  /// null = وضع الإنشاء، غير null = وضع التعديل.
  final EnvelopeEntity? envelope;

  @override
  State<EnvelopeFormSheet> createState() => _EnvelopeFormSheetState();
}

class _EnvelopeFormSheetState extends State<EnvelopeFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _initialBalanceController =
      TextEditingController();

  List<CenterRef> _centers = const [];
  bool _isLoadingCenters = false;
  String? _centersFailure;

  late String _fundType;
  late String? _centerId;
  late Set<String> _selectedCategories;
  bool _categoriesError = false;

  bool get _isEdit => widget.envelope != null;

  @override
  void initState() {
    super.initState();
    final envelope = widget.envelope;
    _fundType = envelope?.fundType ?? AppFundTypes.general;
    _centerId = envelope?.centerId;
    _selectedCategories = envelope?.allowedExpenseCategories.toSet() ?? {};
    if (envelope != null) {
      _nameController.text = envelope.name;
      _purposeController.text = envelope.purpose;
    }
    _loadCenters();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _loadCenters() async {
    setState(() {
      _isLoadingCenters = true;
      _centersFailure = null;
    });
    final result = await sl<EnvelopesRepository>().getCenters();
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoadingCenters = false;
        _centersFailure = failure.message;
      }),
      (centers) => setState(() {
        _isLoadingCenters = false;
        _centers = centers;
      }),
    );
  }

  bool get _isRestricted => _fundType == AppFundTypes.restricted;

  List<String> get _allExpenseCategories {
    final custom = sl.isRegistered<CategoriesService>()
        ? sl<CategoriesService>().expenseCategories.map((c) => c.id).toList()
        : <String>[];
    return {...AppExpenseCategories.all, ...custom}.toList();
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool adding = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة تصنيف مصروف جديد'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'اسم التصنيف *',
                    hintText: 'مثال: جوائز ومسابقات، صيانة سيارات',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'أدخل اسم تصنيف صحيح (حرفين على الأقل)';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: adding ? null : () => Navigator.of(dialogCtx).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: adding
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(dialogCtx);
                      setDialogState(() => adding = true);
                      try {
                        final name = controller.text.trim();
                        await sl<CategoriesService>().addCategory(
                          name: name,
                          type: AppTransactionTypes.expense,
                        );
                        if (!mounted) return;
                        setState(() {
                          // إضافة المعرف تلقائياً إلى المحددات
                          final id = name
                              .replaceAll(RegExp(r'\s+'), '_')
                              .replaceAll(RegExp(r'[^a-zA-Z0-9_\u0600-\u06FF]'), '');
                          _selectedCategories.add(id.isEmpty ? name : id);
                          _categoriesError = false;
                        });
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(content: Text('تمت إضافة التصنيف "$name" بنجاح')),
                        );
                      } catch (e) {
                        setDialogState(() => adding = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('تعذر إضافة التصنيف: $e')),
                        );
                      }
                    },
              child: adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _submit() async {
    // التصنيفات إلزامية للظرف المخصص (فحص محلي — والخادم يتحقق نهائيًا).
    if (_isRestricted && _selectedCategories.isEmpty) {
      setState(() => _categoriesError = true);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.confirmAction,
      message: _isEdit
          ? 'سيتم تحديث بيانات الظرف "${widget.envelope!.name}" على الخادم. '
              'هل تريد المتابعة؟'
          : 'سيتم إنشاء الظرف "${_nameController.text.trim()}" '
              '${_isRestricted ? 'بتصنيفات مخصصة' : 'كسر عام'}'
              '${_initialBalanceController.text.trim().isNotEmpty ? ' ورصيد افتتاحي' : ''}. '
              'هل تريد المتابعة؟',
      confirmLabel: _isEdit ? 'حفظ التعديلات' : 'إنشاء الظرف',
    );
    if (!confirmed || !mounted) return;

    final bloc = context.read<EnvelopesBloc>();
    if (_isEdit) {
      bloc.add(EnvelopesUpdateRequested(UpdateEnvelopeParams(
        envelopeId: widget.envelope!.id,
        name: _nameController.text.trim(),
        purpose: _purposeController.text.trim(),
        allowedExpenseCategories:
            _isRestricted ? _selectedCategories.toList() : const <String>[],
        centerId: _centerId,
        clearCenterId: _centerId == null,
      )));
    } else {
      final balanceText = _initialBalanceController.text.trim();
      final parsedBalance = balanceText.isEmpty
          ? null
          : double.tryParse(balanceText.replaceAll(',', ''));
      bloc.add(EnvelopesCreateRequested(EnvelopeFormParams(
        name: _nameController.text.trim(),
        purpose: _purposeController.text.trim(),
        fundType: _fundType,
        allowedExpenseCategories:
            _isRestricted ? _selectedCategories.toList() : const <String>[],
        centerId: _centerId,
        initialBalance:
            (parsedBalance != null && parsedBalance > 0) ? parsedBalance : null,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnvelopesBloc, EnvelopesState>(
      builder: (context, state) {
        final isSubmitting = state.isSubmitting;
        return Material(
          color: AppColors.surface,
          child: SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.85,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.cardPaddingLarge),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // مقبض النافذة
                        Center(
                          child: Container(
                            width: AppDimensions.bottomSheetHandleWidth,
                            height: AppDimensions.bottomSheetHandleHeight,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmall,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.itemSpacing),
                        Text(
                          _isEdit ? 'تعديل الظرف' : 'إضافة ظرف مالي جديد',
                          style: AppTypography.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.sectionSpacing),

                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppTextField(
                                  label: 'اسم الظرف *',
                                  controller: _nameController,
                                  hintText: 'مثال: صندوق اشتراكات حلقات الفتح',
                                  maxLength: 120,
                                  enabled: !isSubmitting,
                                  validator: (v) => AppValidators.name(v,
                                      fieldName: 'اسم الظرف'),
                                ),
                                const SizedBox(
                                    height: AppDimensions.itemSpacing),
                                AppTextField(
                                  label: 'الغرض (اختياري)',
                                  controller: _purposeController,
                                  hintText: 'ما الغرض من هذا الظرف؟',
                                  maxLines: 3,
                                  maxLength: 500,
                                  enabled: !isSubmitting,
                                  validator: (v) => AppValidators.description(
                                    v,
                                    isRequired: false,
                                    fieldName: 'الغرض',
                                  ),
                                ),
                                const SizedBox(
                                    height: AppDimensions.itemSpacing),

                                // نوع الصندوق (لا يُعدل لاحقًا)
                                const Text('نوع الصندوق *',
                                    style: AppTypography.titleMedium),
                                const SizedBox(height: AppDimensions.spacing8),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: AppFundTypes.general,
                                      label: Text('عام'),
                                      icon: Icon(Icons.public_rounded),
                                    ),
                                    ButtonSegment(
                                      value: AppFundTypes.restricted,
                                      label: Text('مخصص'),
                                      icon: Icon(Icons.lock_outline_rounded),
                                    ),
                                  ],
                                  selected: {_fundType},
                                  // fundType ثابت بعد الإنشاء — يُعطّل في وضع التعديل.
                                  onSelectionChanged: _isEdit || isSubmitting
                                      ? null
                                      : (selection) {
                                          if (selection.isNotEmpty) {
                                            setState(() {
                                              _fundType = selection.first;
                                              _categoriesError = false;
                                            });
                                          }
                                        },
                                ),
                                const SizedBox(height: AppDimensions.spacing8),
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppDimensions.spacing12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isEdit
                                        ? AppColors.warningLight
                                        : AppColors.infoLight,
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMedium,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        _isEdit
                                            ? Icons.warning_amber_rounded
                                            : Icons.info_outline_rounded,
                                        size: AppDimensions.iconMedium,
                                        color: _isEdit
                                            ? AppColors.warning
                                            : AppColors.info,
                                      ),
                                      const SizedBox(
                                        width: AppDimensions.spacing8,
                                      ),
                                      Expanded(
                                        child: Text(
                                          _isEdit
                                              ? 'fundType لا يمكن تعديله لاحقًا'
                                              : 'تنبيه: fundType لا يمكن تعديله لاحقًا — '
                                                  'الظرف العام يقبل كل تصنيفات المصروفات، '
                                                  'والمخصص يقبل تصنيفاته المحددة فقط',
                                          style: AppTypography.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                    height: AppDimensions.itemSpacing),

                                // التصنيفات المسموحة (للمخصص فقط)
                                if (_isRestricted) ...[
                                  const Text(
                                    'التصنيفات المسموحة لهذا الظرف *',
                                    style: AppTypography.titleMedium,
                                  ),
                                  const SizedBox(height: AppDimensions.spacing4),
                                  Text(
                                    'حدد أوجه الصرف المسموح بها حصرًا لهذا الظرف المخصص:',
                                    style: AppTypography.bodySmall
                                        .copyWith(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: AppDimensions.spacing8),
                                  Wrap(
                                    spacing: AppDimensions.spacing8,
                                    runSpacing: AppDimensions.spacing8,
                                    children: [
                                      ..._allExpenseCategories.map((category) {
                                        final selected =
                                            _selectedCategories.contains(category);
                                        return FilterChip(
                                          label: Text(categoryLabel(category)),
                                          selected: selected,
                                          onSelected: isSubmitting
                                              ? null
                                              : (value) => setState(() {
                                                    if (value) {
                                                      _selectedCategories
                                                          .add(category);
                                                    } else {
                                                      _selectedCategories
                                                          .remove(category);
                                                    }
                                                    if (_selectedCategories
                                                        .isNotEmpty) {
                                                      _categoriesError = false;
                                                    }
                                                  }),
                                        );
                                      }),
                                      ActionChip(
                                        avatar: const Icon(Icons.add, size: 18),
                                        label: const Text('تصنيف جديد'),
                                        onPressed: isSubmitting
                                            ? null
                                            : _showAddCategoryDialog,
                                      ),
                                    ],
                                  ),
                                  if (_categoriesError)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppDimensions.spacing8,
                                      ),
                                      child: Text(
                                        'اختر تصنيفًا واحدًا على الأقل للظرف المخصص',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(
                                      height: AppDimensions.itemSpacing),
                                ] else ...[
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppDimensions.spacing12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusMedium,
                                      ),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: AppDimensions.iconSmall,
                                          color: AppColors.success,
                                        ),
                                        const SizedBox(
                                          width: AppDimensions.spacing8,
                                        ),
                                        Expanded(
                                          child: Text(
                                            'الظرف العام يسمح بجميع تصنيفات المصروفات بدون قيود.',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                      height: AppDimensions.itemSpacing),
                                ],

                                // المركز (اختياري)
                                if (_isLoadingCenters)
                                  const AppLoadingView(
                                    message: 'جارٍ تحميل المراكز...',
                                  )
                                else if (_centersFailure != null)
                                  AppErrorView(
                                    message: _centersFailure!,
                                    isCompact: true,
                                    onRetry: _loadCenters,
                                  )
                                else
                                  AppDropdownField<String>(
                                    label: AppStrings.center,
                                    items: _centers
                                        .map((c) => DropdownMenuItem<String>(
                                              value: c.id,
                                              child: Text(c.name),
                                            ))
                                        .toList(),
                                    value:
                                        _centers.any((c) => c.id == _centerId)
                                            ? _centerId
                                            : null,
                                    hint: 'اختر المركز (اختياري)',
                                    enabled: !isSubmitting,
                                    onChanged: (v) =>
                                        setState(() => _centerId = v),
                                  ),
                                const SizedBox(
                                    height: AppDimensions.itemSpacing),

                                // الرصيد الافتتاحي (الإضافة فقط)
                                if (!_isEdit) ...[
                                  AppTextField(
                                    label: '${AppStrings.openingBalance} (ج.م)',
                                    controller: _initialBalanceController,
                                    hintText:
                                        'اتركه فارغًا إن لم يوجد رصيد افتتاحي',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    enabled: !isSubmitting,
                                    validator: (v) {
                                      final text = v?.trim() ?? '';
                                      if (text.isEmpty) return null;
                                      return AppValidators.amount(
                                        text,
                                        fieldName: 'الرصيد الافتتاحي',
                                        allowZero: true,
                                      );
                                    },
                                    helperText:
                                        'يُسجل إيراد رصيد افتتاحي وتخصيص للظرف تلقائيًا',
                                  ),
                                  const SizedBox(
                                      height: AppDimensions.itemSpacing),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppDimensions.sectionSpacing),
                        AppButton(
                          label: _isEdit ? 'حفظ التعديلات' : 'إنشاء الظرف',
                          onPressed: isSubmitting ? null : _submit,
                          isLoading: isSubmitting,
                          icon: Icons.check_rounded,
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        AppButton(
                          label: AppStrings.cancel,
                          variant: AppButtonVariant.text,
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        const Text(
                          AppStrings.serverOnlyWarning,
                          style: AppTypography.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
