import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/loan_form_params.dart';
import '../../domain/repositories/employee_loans_repository.dart';
import '../bloc/employee_loans_bloc.dart';

/// نافذة إنشاء سلفة جديدة لموظف.
///
/// التحقق محلي للتجربة فقط — سيتحقق الخادم نهائيًا من كفاية رصيد الظرف
/// ومن توافق التصنيف (employee_loan) للظرف المخصص.
class LoanFormSheet extends StatefulWidget {
  const LoanFormSheet({super.key});

  @override
  State<LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends State<LoanFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _employeeNameController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<EnvelopeEntity> _envelopes = const [];
  bool _isLoadingEnvelopes = true;
  String? _envelopesFailure;
  String? _envelopeId;

  @override
  void initState() {
    super.initState();
    _loadEnvelopes();
  }

  @override
  void dispose() {
    _employeeNameController.dispose();
    _employeeIdController.dispose();
    _totalAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// قراءة الأظرف النشطة مباشرة عبر المستودع (fetchActiveEnvelopesForLoan)
  /// لعرض الرصيد بجانب كل ظرف.
  Future<void> _loadEnvelopes() async {
    setState(() {
      _isLoadingEnvelopes = true;
      _envelopesFailure = null;
    });
    final result = await sl<EmployeeLoansRepository>().getActiveEnvelopes();
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoadingEnvelopes = false;
        _envelopesFailure = failure.message;
      }),
      (envelopes) => setState(() {
        _isLoadingEnvelopes = false;
        _envelopes = envelopes;
        _envelopeId = null;
      }),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_envelopeId == null) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.confirmAction,
      message: 'سيتم صرف سلفة بمبلغ ${_totalAmountController.text.trim()} ج.م '
          'للموظف "${_employeeNameController.text.trim()}" وخصم المبلغ من '
          'رصيد الظرف المختار. هل تريد المتابعة؟',
      confirmLabel: 'صرف السلفة',
    );
    if (!confirmed || !mounted) return;

    context.read<EmployeeLoansBloc>().add(EmployeeLoansCreateRequested(
          CreateLoanParams(
            employeeName: _employeeNameController.text.trim(),
            employeeId: _employeeIdController.text.trim().isEmpty
                ? null
                : _employeeIdController.text.trim(),
            totalAmount:
                double.tryParse(_totalAmountController.text.trim()) ?? 0,
            envelopeId: _envelopeId!,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeeLoansBloc, EmployeeLoansState>(
      builder: (context, state) {
        final isSubmitting = state.isSubmitting;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.cardPaddingLarge),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const Text(
                    'صرف سلفة جديدة',
                    style: AppTypography.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),

                  AppTextField(
                    label: 'اسم الموظف *',
                    controller: _employeeNameController,
                    hintText: 'الاسم الكامل للموظف',
                    maxLength: 200,
                    enabled: !isSubmitting,
                    validator: (v) =>
                        AppValidators.name(v, fieldName: 'اسم الموظف'),
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),
                  AppTextField(
                    label: 'معرف الموظف',
                    controller: _employeeIdController,
                    hintText: 'رقم وظيفي أو معرف داخلي (اختياري)',
                    maxLength: 128,
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),
                  AppTextField(
                    label: 'إجمالي السلفة (ج.م) *',
                    controller: _totalAmountController,
                    hintText: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: !isSubmitting,
                    validator: (v) =>
                        AppValidators.amount(v, fieldName: 'إجمالي السلفة'),
                    helperText: 'بحد أقصى منزلتين عشريتين',
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),

                  // ظرف الصرف مع عرض الرصيد
                  if (_isLoadingEnvelopes)
                    const AppLoadingView(message: 'جارٍ تحميل الأظرف النشطة...')
                  else if (_envelopesFailure != null)
                    AppErrorView(
                      message: _envelopesFailure!,
                      isCompact: true,
                      onRetry: _loadEnvelopes,
                    )
                  else
                    AppDropdownField<String>(
                      label: 'ظرف الصرف *',
                      items: _envelopes
                          .map((e) => DropdownMenuItem<String>(
                                value: e.id,
                                child: Text(
                                  '${e.name} — الرصيد: ${AppFormatters.amountCompact(e.currentBalance)}',
                                ),
                              ))
                          .toList(),
                      value: _envelopeId,
                      hint: _envelopes.isEmpty
                          ? 'لا توجد أظرف نشطة'
                          : 'اختر الظرف الذي سيُصرف منه المبلغ',
                      enabled: !isSubmitting && _envelopes.isNotEmpty,
                      validator: (v) => v == null ? 'ظرف الصرف مطلوب' : null,
                      onChanged: (v) => setState(() => _envelopeId = v),
                    ),
                  const SizedBox(height: AppDimensions.itemSpacing),

                  AppTextField(
                    label: AppStrings.notes,
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 1000,
                    enabled: !isSubmitting,
                    validator: AppValidators.notes,
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),

                  // تنبيه التحقق الخادمي
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing12),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMedium,
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: AppDimensions.iconMedium,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: AppDimensions.spacing8),
                        Expanded(
                          child: Text(
                            'سيتحقق الخادم من رصيد الظرف وتوافق التصنيف',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),

                  AppButton(
                    label: 'صرف السلفة',
                    onPressed:
                        (_envelopeId == null || isSubmitting) ? null : _submit,
                    isLoading: isSubmitting,
                    icon: Icons.check_rounded,
                  ),
                  const SizedBox(height: AppDimensions.spacing8),
                  AppButton(
                    label: AppStrings.cancel,
                    variant: AppButtonVariant.text,
                    onPressed:
                        isSubmitting ? null : () => Navigator.of(context).pop(),
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
        );
      },
    );
  }
}
