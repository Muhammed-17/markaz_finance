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
import '../../../../core/services/pending_operation_handlers.dart';
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
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/employee_loans_repository.dart';
import '../bloc/employee_loans_bloc.dart';

/// نافذة تسجيل سداد لسلفة موظف.
///
/// عند توفر الإنترنت: تسجيل فوري عبر المعاملة الذرية.
/// عند انقطاع الإنترنت: حفظ كمسودة معلقة (Offline Draft) تُرسل تلقائيًا عند عودة الاتصال.
class LoanRepaySheet extends StatefulWidget {
  const LoanRepaySheet({required this.loan, this.draft, super.key});

  final EmployeeLoanEntity loan;

  /// مسودة مرفوضة يُعاد تعديلها وإرسالها: تُعبَّأ القيم منها، وتُحذف عند نجاح
  /// البديلة (بمعرّف طلب جديد لأن الخادم لم يعتمد القديمة).
  final PendingOperationModel? draft;

  @override
  State<LoanRepaySheet> createState() => _LoanRepaySheetState();
}

class _LoanRepaySheetState extends State<LoanRepaySheet> {
  /// يُولَّد مرة واحدة لنافذة السداد ويُستخدم في المحاولة المباشرة والمسودة معًا،
  /// فإن انتهت المهلة بعد التزام ناجح على الخادم لا يتكرر السداد عند المزامنة.
  final String _requestId = const Uuid().v4();
  bool _handlingTransient = false;
  String? _draftEnvelopeId;

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
    final draft = widget.draft;
    if (draft != null) {
      final amount = draft.payload['amount'];
      if (amount is num) _amountController.text = amount.toString();
      _notesController.text = (draft.payload['notes'] as String?) ?? '';
      _draftEnvelopeId = draft.payload['envelopeId'] as String?;
    }
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
        // تعديل مسودة: نختار ظرفها السابق إن كان ما زال نشطًا (وإلا يختار المستخدم).
        if (_envelopeId == null &&
            _draftEnvelopeId != null &&
            envelopes.any((e) => e.id == _draftEnvelopeId)) {
          _envelopeId = _draftEnvelopeId;
        }
      }),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_envelopeId == null) return;

    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) return;

    if (!await _confirmDespitePending(amount) || !mounted) return;

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

      await _saveDraft(amount);
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
          requestId: _requestId,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ));
  }

  /// حذف المسودة المرفوضة التي يحلّ هذا السداد محلها (عند نجاح البديل فقط).
  void _discardReplacedDraft() {
    final id = widget.draft?.id;
    if (id != null) sl<PendingOperationsService>().deleteOperation(id);
  }

  /// تنبيه قبل تسجيل سداد جديد لسلفة لها سداد معلّق: قد يكون تكرارًا، وقد يتجاوز
  /// مجموعهما المتبقي فيُرفض الثاني عند المزامنة.
  Future<bool> _confirmDespitePending(double amount) async {
    final pending = sl<PendingOperationsService>()
        .activeRepaymentsForLoan(widget.loan.id, excludeId: widget.draft?.id);
    if (pending.isEmpty) return true;

    final total = PendingOperationsService.sumAmount(pending);
    final exceeds = Money.fromUnits(total + amount) >
        Money.fromUnits(widget.loan.remainingBalance);
    final message = 'لهذه السلفة ${pending.length} سداد معلّق بمجموع '
        '${AppFormatters.amount(total)} لم يُعتمد بعد. '
        '${exceeds ? 'مجموعه مع هذا المبلغ يتجاوز المتبقي، فسيُرفض أحدهما عند المزامنة. ' : 'قد يكون هذا السداد مكررًا. '}'
        'هل تريد المتابعة؟';
    return showAppConfirmDialog(
      context,
      title: 'يوجد سداد معلّق لهذه السلفة',
      message: message,
      confirmLabel: 'متابعة',
      useRootNavigator: true,
    );
  }

  /// حفظ السداد كمسودة معلقة في Hive بنفس requestId الخاص بالنافذة.
  Future<void> _saveDraft(double amount) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    final pendingOp = PendingOperationModel(
      id: _requestId, // id === requestId: معرّف واحد لمنع التكرار
      ownerUid: ownerUid,
      type: AppFunctions.repayLoan,
      title:
          'سداد سلفة: ${widget.loan.employeeName} (${AppFormatters.amount(amount)})',
      payload: <String, dynamic>{
        'loanId': widget.loan.id,
        'amount': amount,
        'envelopeId': _envelopeId!,
        'requestId': _requestId,
        'notes': notes,
      },
      createdAt: DateTime.now(),
      schemaVersion: RepayLoanHandler.schemaVersion,
    );

    await sl<PendingOperationsService>().saveOperation(pendingOp);
    _discardReplacedDraft();
    if (!mounted) return;
    showAppSnackBar(
      context,
      message:
          'تم حفظ العملية كمسودة معلقة — ستتم المزامنة تلقائيًا فور توفر الإنترنت',
    );
    Navigator.of(context).pop();
  }

  /// فشل مباشر بسبب الشبكة/المهلة: قد يكون الخادم نفّذ الطلب فعلًا وضاع الرد،
  /// فنعرض حفظه كمسودة بنفس requestId بدل إعادة المحاولة بمعرّف جديد.
  Future<void> _offerDraftAfterTransientFailure() async {
    if (_handlingTransient || !mounted) return;
    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0 || _envelopeId == null) return;
    _handlingTransient = true;
    try {
      final confirmed = await showAppConfirmDialog(
        context,
        title: 'تعذّر الوصول إلى الخادم',
        message: 'لم يصلنا رد من الخادم، وقد يكون السداد سُجّل فعلًا. لتفادي '
            'تسجيله مرتين، سيُحفظ كمسودة معلقة بالمعرّف نفسه وتتم مزامنته '
            'تلقائيًا (ولن يتكرر). هل تريد المتابعة؟',
        confirmLabel: 'حفظ كمسودة',
        useRootNavigator: true,
      );
      if (!confirmed || !mounted) return;
      await _saveDraft(amount);
    } finally {
      _handlingTransient = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<EmployeeLoansBloc, EmployeeLoansState>(
          listenWhen: (previous, state) =>
              previous.isSubmitting &&
              state.status == EmployeeLoansStatus.operationFailure &&
              state.lastOperation == EmployeeLoansOperation.repay &&
              state.failure != null &&
              PendingOperationsService.isTransientFailureModel(state.failure!),
          listener: (context, state) => _offerDraftAfterTransientFailure(),
        ),
        BlocListener<EmployeeLoansBloc, EmployeeLoansState>(
          listenWhen: (previous, state) =>
              previous.isSubmitting &&
              state.status == EmployeeLoansStatus.operationCompleted &&
              state.lastOperation == EmployeeLoansOperation.repay,
          listener: (context, state) => _discardReplacedDraft(),
        ),
      ],
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
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
