import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/audit_log_entities.dart';
import '../../../../core/domain/entities/employee_loan_entity.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_amount_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/usecases/employee_loans_usecases.dart';
import '../bloc/employee_loans_bloc.dart';
import 'loan_repay_sheet.dart';

/// صفحة تفاصيل سلفة موظف (loanId من مسار الصفحة):
/// معلومات السلفة + تسجيل السداد + المدفوعات + سجل التدقيق للمخوّلين.
class LoanDetailsPage extends StatefulWidget {
  const LoanDetailsPage({required this.loanId, super.key});

  final String loanId;

  @override
  State<LoanDetailsPage> createState() => _LoanDetailsPageState();
}

class _LoanDetailsPageState extends State<LoanDetailsPage> {
  late final Stream<List<EmployeeLoanEntity>> _loansStream;

  List<LoanPaymentEntity> _payments = const [];
  List<LoanLogEntity> _logs = const [];
  bool _isLoadingPayments = true;
  bool _isLoadingLogs = true;
  String? _paymentsFailure;
  String? _logsFailure;
  bool _isSheetOpen = false;
  NavigatorState? _openSheetNavigator;

  @override
  void initState() {
    super.initState();
    // بث ثابت يُنشأ مرة واحدة — لا يعاد الاشتراك فيه عند كل إعادة بناء.
    _loansStream = sl<WatchLoans>().call();
    _loadPayments();
    if (_canViewLogs) _loadLogs();
  }

  UserProfileEntity? get _currentProfile {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.profile : null;
  }

  /// سجل التدقيق يظهر للمخوّلين فقط (كما في تفاصيل الحركات).
  bool get _canViewLogs =>
      PermissionService.canAny(
        _currentProfile,
        [PermissionAction.cancel, PermissionAction.approve],
      ) ||
      PermissionService.isAdmin(_currentProfile);

  bool get _canRepay =>
      PermissionService.can(_currentProfile, PermissionAction.create);

  Future<void> _loadPayments() async {
    setState(() {
      _isLoadingPayments = true;
      _paymentsFailure = null;
    });
    final result = await sl<GetLoanPayments>().call(widget.loanId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoadingPayments = false;
        _paymentsFailure = failure.message;
      }),
      (payments) => setState(() {
        _isLoadingPayments = false;
        _payments = payments;
      }),
    );
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoadingLogs = true;
      _logsFailure = null;
    });
    final result = await sl<GetLoanLogs>().call(widget.loanId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoadingLogs = false;
        _logsFailure = failure.message;
      }),
      (logs) => setState(() {
        _isLoadingLogs = false;
        _logs = logs;
      }),
    );
  }

  Future<void> _openRepaySheet(EmployeeLoanEntity loan) async {
    setState(() => _isSheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusExtraLarge),
        ),
      ),
      builder: (sheetContext) {
        _openSheetNavigator = Navigator.of(sheetContext);
        return BlocProvider<EmployeeLoansBloc>.value(
          value: context.read<EmployeeLoansBloc>(),
          child: LoanRepaySheet(loan: loan),
        );
      },
    );
    if (mounted) {
      setState(() => _isSheetOpen = false);
      _openSheetNavigator = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EmployeeLoansBloc>(
      create: (_) => sl<EmployeeLoansBloc>(),
      child: BlocConsumer<EmployeeLoansBloc, EmployeeLoansState>(
        listener: (context, state) {
          final message = state.message;
          if (message != null) {
            showAppSnackBar(
              context,
              message: message,
              isError: state.status == EmployeeLoansStatus.operationFailure,
            );
          }
          // نجاح السداد: إغلاق النافذة وتحديث المدفوعات والسجل.
          if (state.status == EmployeeLoansStatus.operationCompleted &&
              state.lastOperation == EmployeeLoansOperation.repay) {
            if (_isSheetOpen) {
              _openSheetNavigator?.pop();
              setState(() => _isSheetOpen = false);
            }
            _loadPayments();
            if (_canViewLogs) _loadLogs();
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل السلفة')),
            body: StreamBuilder<List<EmployeeLoanEntity>>(
              stream: _loansStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const AppLoadingView(message: AppStrings.loading);
                }
                if (snapshot.hasError) {
                  return AppErrorView(
                    message: 'تعذر تحميل بيانات السلفة، حاول مرة أخرى',
                    onRetry: () => setState(() {}),
                  );
                }
                EmployeeLoanEntity? loan;
                final loans = snapshot.data ?? const <EmployeeLoanEntity>[];
                for (final l in loans) {
                  if (l.id == widget.loanId) {
                    loan = l;
                    break;
                  }
                }
                if (loan == null) {
                  return const AppErrorView(
                    message:
                        'السلفة غير موجودة في القائمة الحالية — عد إلى القائمة وافتحها من هناك',
                  );
                }
                return _LoanDetailsBody(
                  loan: loan,
                  payments: _payments,
                  logs: _logs,
                  isLoadingPayments: _isLoadingPayments,
                  isLoadingLogs: _isLoadingLogs,
                  paymentsFailure: _paymentsFailure,
                  logsFailure: _logsFailure,
                  canRepay: _canRepay,
                  canViewLogs: _canViewLogs,
                  onRepay: () => _openRepaySheet(loan!),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LoanDetailsBody extends StatelessWidget {
  const _LoanDetailsBody({
    required this.loan,
    required this.payments,
    required this.logs,
    required this.isLoadingPayments,
    required this.isLoadingLogs,
    required this.paymentsFailure,
    required this.logsFailure,
    required this.canRepay,
    required this.canViewLogs,
    required this.onRepay,
  });

  final EmployeeLoanEntity loan;
  final List<LoanPaymentEntity> payments;
  final List<LoanLogEntity> logs;
  final bool isLoadingPayments;
  final bool isLoadingLogs;
  final String? paymentsFailure;
  final String? logsFailure;
  final bool canRepay;
  final bool canViewLogs;
  final VoidCallback onRepay;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
          children: [
            // ملخص السلفة
            _SummaryCard(loan: loan),
            const SizedBox(height: AppDimensions.itemSpacing),

            // بيانات السلفة
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بيانات السلفة',
                      style: AppTypography.headlineSmall),
                  const SizedBox(height: AppDimensions.spacing12),
                  AppInfoRow(
                    label: 'الإجمالي',
                    value: AppFormatters.amount(loan.totalAmount),
                  ),
                  AppInfoRow(
                    label: 'المتبقي',
                    value: AppFormatters.amount(loan.remainingBalance),
                  ),
                  AppInfoRow(
                    label: AppStrings.status,
                    value: loan.isActive
                        ? AppStrings.statusActive
                        : AppStrings.statusPaidOff,
                  ),
                  AppInfoRow(
                    label: 'نسبة السداد',
                    value: AppFormatters.percent(loan.paidRatio),
                  ),
                  if (loan.employeeId != null &&
                      loan.employeeId!.trim().isNotEmpty)
                    AppInfoRow(
                      label: 'معرف الموظف',
                      value: loan.employeeId!,
                    ),
                  AppInfoRow(
                    label: AppStrings.notes,
                    value: AppFormatters.orDash(loan.notes),
                  ),
                  AppInfoRow(
                    label: 'معرف السلفة',
                    value: loan.id,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),

            // زر تسجيل السداد
            if (canRepay && loan.isActive)
              AppButton(
                label: 'تسجيل سداد',
                icon: Icons.payments_rounded,
                onPressed: onRepay,
              ),
            if (canRepay && loan.isActive)
              const SizedBox(height: AppDimensions.sectionSpacing),

            // المدفوعات
            _PaymentsCard(
              payments: payments,
              isLoading: isLoadingPayments,
              failure: paymentsFailure,
              onRetry: () => context
                  .findAncestorStateOfType<_LoanDetailsPageState>()
                  ?._loadPayments(),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),

            // سجل التدقيق (للمخوّلين)
            if (canViewLogs) ...[
              _LoanLogsCard(
                logs: logs,
                isLoading: isLoadingLogs,
                failure: logsFailure,
                onRetry: () => context
                    .findAncestorStateOfType<_LoanDetailsPageState>()
                    ?._loadLogs(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.loan});

  final EmployeeLoanEntity loan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor:
          loan.isActive ? AppColors.successLight : AppColors.infoLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'سلفة - ${loan.employeeName}',
                  style: AppTypography.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppStatusChip(
                label: loan.isActive
                    ? AppStrings.statusActive
                    : AppStrings.statusPaidOff,
                color: loan.isActive ? AppColors.success : AppColors.info,
                backgroundColor: AppColors.surface,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Row(
            children: [
              const Text('المتبقي: ', style: AppTypography.bodyMedium),
              AppAmountText(
                amount: loan.remainingBalance,
                isIncome: false,
                showSign: false,
              ),
              const Spacer(),
              Text(
                'من ${AppFormatters.amount(loan.totalAmount)}',
                style: AppTypography.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          LinearProgressIndicator(
            value: loan.paidRatio,
            minHeight: AppDimensions.bottomSheetHandleHeight + 2,
            backgroundColor: AppColors.surface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
        ],
      ),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({
    required this.payments,
    required this.isLoading,
    required this.failure,
    required this.onRetry,
  });

  final List<LoanPaymentEntity> payments;
  final bool isLoading;
  final String? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل المدفوعات', style: AppTypography.headlineSmall),
          const SizedBox(height: AppDimensions.spacing12),
          if (isLoading)
            const AppLoadingView(message: 'جارٍ تحميل المدفوعات...')
          else if (failure != null)
            AppErrorView(message: failure!, isCompact: true, onRetry: onRetry)
          else if (payments.isEmpty)
            const AppEmptyView(
              message: 'لا توجد مدفوعات مسجلة بعد',
              isCompact: true,
            )
          else
            ...payments.map((payment) => Container(
                  margin: const EdgeInsets.only(
                    bottom: AppDimensions.spacing8,
                  ),
                  padding: const EdgeInsets.all(AppDimensions.spacing12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppAmountText(
                            amount: payment.paidAmount,
                            isIncome: true,
                          ),
                          const Spacer(),
                          Text(
                            AppFormatters.dateTime(payment.paymentDate),
                            style: AppTypography.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacing4),
                      Text(
                        'معرّف الحركة: ${payment.transactionId}',
                        style: AppTypography.labelSmall,
                      ),
                      if (payment.notes.trim().isNotEmpty)
                        Text(
                          payment.notes,
                          style: AppTypography.bodySmall,
                        ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _LoanLogsCard extends StatelessWidget {
  const _LoanLogsCard({
    required this.logs,
    required this.isLoading,
    required this.failure,
    required this.onRetry,
  });

  final List<LoanLogEntity> logs;
  final bool isLoading;
  final String? failure;
  final VoidCallback onRetry;

  String _actionLabel(String actionType) {
    switch (actionType) {
      case AppLogActions.create:
        return 'إنشاء';
      case AppLogActions.update:
        return 'تعديل';
      case AppLogActions.payment:
        return 'سداد';
      case AppLogActions.payoff:
        return 'إغلاق السلفة';
      default:
        return actionType;
    }
  }

  Color _actionColor(String actionType) {
    switch (actionType) {
      case AppLogActions.payoff:
        return AppColors.success;
      case AppLogActions.payment:
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.auditLog, style: AppTypography.headlineSmall),
          const SizedBox(height: AppDimensions.spacing12),
          if (isLoading)
            const AppLoadingView(message: 'جارٍ تحميل السجل...')
          else if (failure != null)
            AppErrorView(message: failure!, isCompact: true, onRetry: onRetry)
          else if (logs.isEmpty)
            const AppEmptyView(
              message: 'لا توجد سجلات تدقيق لهذه السلفة',
              isCompact: true,
            )
          else
            ...logs.map((log) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.spacing12,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spacing12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppStatusChip(
                              label: _actionLabel(log.actionType),
                              color: _actionColor(log.actionType),
                              backgroundColor: AppColors.surface,
                            ),
                            const Spacer(),
                            Text(
                              AppFormatters.dateTime(log.timestamp),
                              style: AppTypography.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacing8),
                        Text(
                          'بواسطة: ${log.performedByName}',
                          style: AppTypography.bodySmall,
                        ),
                        if (log.reason != null && log.reason!.isNotEmpty)
                          Text(
                            'السبب: ${log.reason}',
                            style: AppTypography.bodySmall,
                          ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
