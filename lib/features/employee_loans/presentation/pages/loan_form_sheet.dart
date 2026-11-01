import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/services/operation_submitter.dart';
import '../../../../core/services/pending_operation_handlers.dart';
import '../../../../core/services/pending_operations_service.dart';
import '../../../../core/services/permission_service.dart';
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
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../users/domain/usecases/users_usecases.dart';
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
  /// يُولَّد مرة واحدة للنافذة: للمحاولة المباشرة والمسودة معًا، فإن ضاع الرد
  /// بعد صرف ناجح لا تُصرف السلفة مرتين عند المزامنة.
  final String _requestId = const Uuid().v4();
  bool _handlingTransient = false;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySub;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // الموظف يُختار من حسابات النظام النشطة (مستخدم أو مدير).
  List<UserProfileEntity> _users = const [];
  bool _isLoadingUsers = true;
  String? _usersFailure;
  String? _selectedUserId;

  List<EnvelopeEntity> _envelopes = const [];
  bool _isLoadingEnvelopes = true;
  String? _envelopesFailure;
  String? _envelopeId;
  // عدد الأظرف المخصصة المستبعدة لأنها لا تشمل بند «سلف الموظفين».
  int _hiddenEnvelopes = 0;

  @override
  void initState() {
    super.initState();
    _isOnline = sl<ConnectivityService>().isOnline;
    _connectivitySub =
        sl<ConnectivityService>().onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    _loadUsers();
    _loadEnvelopes();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _totalAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// قراءة حسابات المستخدمين النشطة (مستخدم عادي أو مدير نظام) لقائمة الموظفين.
  ///
  /// مدير النظام يرى كل الحسابات؛ المستخدم العادي يرى حسابه فقط (ويُختار تلقائيًا)
  /// — قواعد Firestore تمنع غير المدير من قراءة قائمة المستخدمين.
  /// عند الفشل تظهر رسالة الخطأ هنا مع زر إعادة المحاولة.
  Future<void> _loadUsers() async {
    final authState = context.read<AuthBloc>().state;
    final me = authState is AuthAuthenticated ? authState.profile : null;
    if (!PermissionService.isAdmin(me)) {
      setState(() {
        _isLoadingUsers = false;
        _usersFailure = null;
        _users = me == null || !me.isActive ? const [] : [me];
        _selectedUserId = _users.isEmpty ? null : me!.id;
      });
      return;
    }
    setState(() {
      _isLoadingUsers = true;
      _usersFailure = null;
    });
    try {
      final users = await sl<WatchUsers>()()
          .first
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final active = users.where((u) => u.isActive).toList();
      setState(() {
        _isLoadingUsers = false;
        _users = active;
        if (!active.any((u) => u.id == _selectedUserId)) _selectedUserId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingUsers = false;
        _usersFailure =
            e is Failure ? e.message : 'تعذّر تحميل قائمة الحسابات';
      });
    }
  }

  UserProfileEntity? get _selectedUser {
    for (final u in _users) {
      if (u.id == _selectedUserId) return u;
    }
    return null;
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
        // الظرف العام يصلح دائمًا، والمخصص فقط إن كان بند employee_loan ضمن
        // تصنيفاته المسموحة (وإلا ترفض القواعد صرف السلفة منه).
        final eligible = envelopes
            .where((e) => e.allowsExpenseCategory(AppExpenseCategories.employeeLoan))
            .toList();
        _hiddenEnvelopes = envelopes.length - eligible.length;
        _envelopes = eligible;
        _envelopeId = null;
      }),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final employee = _selectedUser;
    if (_envelopeId == null || employee == null) return;

    if (!_isOnline) {
      final saveDraft = await showAppConfirmDialog(
        context,
        title: 'حفظ كمسودة سلفة معلقة',
        message: 'أنت غير متصل بالإنترنت. ستُحفظ السلفة كمسودة على هذا الجهاز '
            'ولن يُخصم شيء من رصيد الظرف حتى تتوفر الشبكة وتتم المزامنة '
            '(وقد تُرفض حينها إن لم يعد الرصيد كافيًا). هل تريد المتابعة؟',
        confirmLabel: 'حفظ كمسودة',
        useRootNavigator: true,
      );
      if (!saveDraft || !mounted) return;
      await _saveDraft();
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.confirmAction,
      message: 'سيتم صرف سلفة بمبلغ ${_totalAmountController.text.trim()} ج.م '
          'للموظف "${employee.name}" وخصم المبلغ من '
          'رصيد الظرف المختار. هل تريد المتابعة؟',
      confirmLabel: 'صرف السلفة',
    );
    if (!confirmed || !mounted) return;

    context.read<EmployeeLoansBloc>().add(EmployeeLoansCreateRequested(
          CreateLoanParams(
            employeeName: employee.name,
            employeeId: employee.id,
            totalAmount:
                double.tryParse(_totalAmountController.text.trim()) ?? 0,
            envelopeId: _envelopeId!,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            requestId: _requestId,
          ),
        ));
  }

  /// بيانات الصرف كما يرسلها المعالج (بدون requestId — يضيفه المرسل).
  Map<String, dynamic> _payload(UserProfileEntity employee) => {
        'employeeName': employee.name,
        'employeeId': employee.id,
        'totalAmount': double.tryParse(_totalAmountController.text.trim()) ?? 0,
        'envelopeId': _envelopeId,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

  Future<void> _saveDraft() async {
    final employee = _selectedUser;
    if (employee == null || _envelopeId == null) return;
    try {
      await sl<OperationSubmitter>().saveAsDraft(
        handler: const CreateEmployeeLoanHandler(),
        requestId: _requestId,
        title: 'صرف سلفة: ${employee.name} '
            '(${_totalAmountController.text.trim()} ج.م)',
        payload: _payload(employee),
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: e is Failure ? e.message : 'تعذّر حفظ المسودة',
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    showAppSnackBar(
      context,
      message:
          'تم حفظ السلفة كمسودة معلقة — ستتم المزامنة تلقائيًا فور توفر الإنترنت',
    );
    Navigator.of(context).pop();
  }

  /// فشل مباشر بسبب الشبكة/المهلة: قد يكون الخادم صرف السلفة فعلًا وضاع الرد،
  /// فنعرض حفظها كمسودة بنفس requestId بدل إعادة المحاولة بمعرّف جديد.
  Future<void> _offerDraftAfterTransientFailure() async {
    if (_handlingTransient || !mounted) return;
    _handlingTransient = true;
    try {
      final confirmed = await showAppConfirmDialog(
        context,
        title: 'تعذّر الوصول إلى الخادم',
        message: 'لم يصلنا رد من الخادم، وقد تكون السلفة صُرفت فعلًا. لتفادي '
            'صرفها مرتين، ستُحفظ كمسودة معلقة بالمعرّف نفسه وتتم مزامنتها '
            'تلقائيًا (ولن تتكرر). هل تريد المتابعة؟',
        confirmLabel: 'حفظ كمسودة',
        useRootNavigator: true,
      );
      if (!confirmed || !mounted) return;
      await _saveDraft();
    } finally {
      _handlingTransient = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EmployeeLoansBloc, EmployeeLoansState>(
      listenWhen: (previous, state) =>
          previous.isSubmitting &&
          state.status == EmployeeLoansStatus.operationFailure &&
          state.lastOperation == EmployeeLoansOperation.create &&
          state.failure != null &&
          PendingOperationsService.isTransientFailureModel(state.failure!),
      listener: (context, state) => _offerDraftAfterTransientFailure(),
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
                    'صرف سلفة جديدة',
                    style: AppTypography.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),

                  if (_isLoadingUsers)
                    const AppLoadingView(message: 'جارٍ تحميل الحسابات...')
                  else if (_usersFailure != null)
                    AppErrorView(
                      message: _usersFailure!,
                      isCompact: true,
                      onRetry: _loadUsers,
                    )
                  else
                    AppDropdownField<String>(
                      label: 'اسم الموظف *',
                      items: _users
                          .map((u) => DropdownMenuItem<String>(
                                value: u.id,
                                child: Text(
                                  u.isAdmin ? '${u.name} — مدير نظام' : u.name,
                                ),
                              ))
                          .toList(),
                      value: _selectedUserId,
                      hint: _users.isEmpty
                          ? 'لا توجد حسابات نشطة'
                          : 'اختر الموظف من حسابات المستخدمين',
                      enabled: !isSubmitting && _users.isNotEmpty,
                      validator: (v) => v == null ? 'اسم الموظف مطلوب' : null,
                      onChanged: (v) => setState(() => _selectedUserId = v),
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
                          ? (_hiddenEnvelopes > 0
                              ? 'لا يوجد ظرف يسمح بصرف السلف'
                              : 'لا توجد أظرف نشطة')
                          : 'اختر الظرف الذي سيُصرف منه المبلغ',
                      enabled: !isSubmitting && _envelopes.isNotEmpty,
                      validator: (v) => v == null ? 'ظرف الصرف مطلوب' : null,
                      onChanged: (v) => setState(() => _envelopeId = v),
                    ),
                  if (!_isLoadingEnvelopes &&
                      _envelopesFailure == null &&
                      _hiddenEnvelopes > 0) ...[
                    const SizedBox(height: AppDimensions.spacing8),
                    const Text(
                      'تُعرض الأظرف العامة والمخصصة التي تتضمن بند «سلف الموظفين» فقط.',
                      style: AppTypography.labelSmall,
                    ),
                  ],
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
                    onPressed: (_envelopeId == null ||
                            _selectedUserId == null ||
                            isSubmitting)
                        ? null
                        : _submit,
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
