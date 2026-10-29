import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/data/models/pending_operation_model.dart';
import '../../../../core/domain/entities/employee_loan_entity.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/services/pending_operations_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/repositories/employee_loans_repository.dart';
import '../bloc/employee_loans_bloc.dart';

/// نافذة تسجيل سداد لسلفة موظف.
///
/// عند توفر الإنترنت: تسجيل فوري عبر المعاملة الذرية.
/// عند انقطاع الإنترنت: حفظ كمسودة معلقة (Offline Draft) تُرسل تلقائيًا عند عودة الاتصال.
class LoanRepaySheet extends StatefulWidget {
  const LoanRepaySheet({required this.loan, super.key});

  final EmployeeLoanEntity loan;

  @override
  State<LoanRepaySheet> createState() => _LoanRepaySheetState();
}

class _LoanRepaySheetState extends State<LoanRepaySheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<EnvelopeEntity> _envelopes = const [];
  bool _isLoadingEnvelopes = true;
  String? _envelopesFailure;
  String? _envelopeId;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _isOnline = sl<ConnectivityService>().isOnline;
    _connectivitySub =
        sl<ConnectivityService>().onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    _loadEnvelopes();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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
      }),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_envelopeId == null) return;

    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    // في وضع عدم الاتصال: حفظ كمسودة معلقة في Hive
    if (!_isOnline) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: 'حفظ كمسودة سداد معلقة',
        message: 'أنت غير متصل بالإنترنت حاليًا. سيتم حفظ السداد بمبلغ '
            '${AppFormatters.amount(amount)} كمسودة معلقة على هذا الجهاز، '
            'ولن يتغير رصيد السلفة أو الظرف حتى تتوفر الشبكة وتتم المزامنة. '
            'هل تريد المتابعة؟',
        confirmLabel: 'حفظ كمسودة',
        useRootNavigator: true,
      );
      if (!confirmed || !mounted) return;

      // id يُولَّد مرة واحدة هنا ويُستخدم كـ requestId لمنع التكرار على الخادم.
      // إنشاؤه عند الحفظ (لا عند التنفيذ) يضمن نفس المعرّف في كل محاولة إعادة إرسال.
      final requestId = const Uuid().v4();
      final ownerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      final pendingOp = PendingOperationModel(
        id: requestId, // id === requestId: معرّف واحد لمنع التكرار
        ownerUid: ownerUid,
        type: AppFunctions.repayLoan,
        title:
            'سداد سلفة: ${widget.loan.employeeName} (${AppFormatters.amount(amount)})',
        payload: <String, dynamic>{
          'loanId': widget.loan.id,
          'amount': amount,
          'envelopeId': _envelopeId!,
          'requestId': requestId,
          'notes': notes,
        },
        createdAt: DateTime.now(),
      );

      await sl<PendingOperationsService>().saveOperation(pendingOp);
      if (!mounted) return;
      showAppSnackBar(
        context,
        message:
            'تم حفظ العملية كمسودة معلقة — ستتم المزامنة تلقائيًا فور توفر الإنترنت',
      );
      Navigator.of(context).pop();
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'تأكيد السداد',
      message: 'سيتم تسجيل سداد بمبلغ ${AppFormatters.amount(amount)} لسلفة '
          'الموظف "${widget.loan.employeeName}" واستلام المبلغ نقدًا في '
          'الظرف المختار. هل تريد المتابعة؟',
      confirmLabel: 'تسجيل السداد',
      useRootNavigator: true,
    );
    if (!confirmed || !mounted) return;

    context.read<EmployeeLoansBloc>().add(EmployeeLoansRepayRequested(
          loanId: widget.loan.id,
          amount: amount,
          envelopeId: _envelopeId!,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
                    'تسجيل سداد',
                    style: AppTypography.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacing4),
                  Text(
                    'سلفة الموظف: ${widget.loan.employeeName} — '
                    'المتبقي: ${AppFormatters.amount(widget.loan.remainingBalance)}',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),

                  // المبلغ
                  AppTextField(
                    label: '${AppStrings.amount} (ج.م) *',
                    controller: _amountController,
                    hintText: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: !isSubmitting,
                    validator: (v) {
                      final base = AppValidators.amount(
                        v,
                        fieldName: 'مبلغ السداد',
                      );
                      if (base != null) return base;
                      final parsed = double.tryParse(
                        v?.trim().replaceAll(',', '') ?? '',
                      );
                      final remaining = widget.loan.remainingBalance;
                      if (parsed != null &&
                          Money.fromUnits(parsed) >
                              Money.fromUnits(remaining)) {
                        return 'مبلغ السداد يتجاوز المتبقي '
                            '(${AppFormatters.amountCompact(remaining)})';
                      }
                      return null;
                    },
                    helperText: 'بحد أقصى منزلتين عشريتين',
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),

                  // ظرف استلام المبلغ
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
                      label: 'ظرف استلام المبلغ *',
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
                          : 'اختر الظرف الذي استُلم فيه المبلغ',
                      enabled: !isSubmitting && _envelopes.isNotEmpty,
                      validator: (v) => v == null ? 'ظرف الاستلام مطلوب' : null,
                      onChanged: (v) => setState(() => _envelopeId = v),
                    ),
                  const SizedBox(height: AppDimensions.itemSpacing),

                  // الملاحظات
                  AppTextField(
                    label: AppStrings.notes,
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 1000,
                    enabled: !isSubmitting,
                    validator: AppValidators.notes,
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),

                  // تنبيه آلية السداد أو وضع عدم الاتصال
                  if (!_isOnline)
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
                            Icons.wifi_off_rounded,
                            size: AppDimensions.iconMedium,
                            color: AppColors.warning,
                          ),
                          SizedBox(width: AppDimensions.spacing8),
                          Expanded(
                            child: Text(
                              'أنت غير متصل بالإنترنت حاليًا. سيتم حفظ السداد كمسودة معلقة تُرسل تلقائيًا فور عودة الاتصال دون التأثير على الأرصدة حتى اعتمادها.',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacing12),
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMedium,
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: AppDimensions.iconMedium,
                            color: AppColors.info,
                          ),
                          SizedBox(width: AppDimensions.spacing8),
                          Expanded(
                            child: Text(
                              'سيخصم المبلغ من المتبقي ويزيد رصيد الظرف المختار — '
                              'منع التكرار مضمون على الخادم عبر requestId',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppDimensions.sectionSpacing),

                  AppButton(
                    label: _isOnline ? 'تسجيل السداد' : 'حفظ كمسودة سداد معلقة',
                    onPressed:
                        (_envelopeId == null || isSubmitting) ? null : _submit,
                    isLoading: isSubmitting,
                    icon: _isOnline
                        ? Icons.payments_rounded
                        : Icons.save_as_rounded,
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
