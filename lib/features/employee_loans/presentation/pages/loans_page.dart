import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/employee_loan_entity.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_stat_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../bloc/employee_loans_bloc.dart';
import 'loan_form_sheet.dart';

/// صفحة سلف الموظفين: إحصاءات + تصفية بالحالة + قائمة السلف.
class LoansPage extends StatefulWidget {
  const LoansPage({super.key});

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  /// هل توجد نافذة سفلية مفتوحة الآن؟ (لإغلاقها عند نجاح العملية فقط)
  bool _isSheetOpen = false;
  late final EmployeeLoansBloc _loansBloc;

  UserProfileEntity? get _currentProfile {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.profile : null;
  }

  bool get _canCreate =>
      PermissionService.can(_currentProfile, PermissionAction.create);

  @override
  void initState() {
    super.initState();
    _loansBloc = sl<EmployeeLoansBloc>()
      ..add(const EmployeeLoansLoadRequested());
  }

  @override
  void dispose() {
    _loansBloc.close();
    super.dispose();
  }

  Future<void> _openFormSheet() async {
    setState(() => _isSheetOpen = true);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: BlocProvider<EmployeeLoansBloc>.value(
            value: _loansBloc,
            child: const LoanFormSheet(),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _isSheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _loansBloc,
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
          // إغلاق نافذة النموذج بعد نجاح العملية فقط.
          if (state.status == EmployeeLoansStatus.operationCompleted &&
              _isSheetOpen) {
            Navigator.of(context).pop();
            setState(() => _isSheetOpen = false);
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // شريط الأدوات
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: AppStrings.search,
                            hintText: 'ابحث باسم الموظف...',
                            prefixIcon: Icons.search_rounded,
                            onChanged: (v) => context
                                .read<EmployeeLoansBloc>()
                                .add(EmployeeLoansSearchQueryChanged(v)),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacing12),
                        AppButton(
                          label: 'سلفة جديدة',
                          icon: Icons.add_rounded,
                          isFullWidth: false,
                          onPressed: _canCreate ? () => _openFormSheet() : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.itemSpacing),

                    // بطاقتا الإحصاء (من القائمة المحملة محليًا)
                    Row(
                      children: [
                        Expanded(
                          child: AppStatCard(
                            title: AppStrings.activeLoans,
                            value: AppFormatters.amount(
                              state.activeTotalAmount,
                            ),
                            icon: Icons.handshake_outlined,
                            iconColor: AppColors.primary,
                            iconBackground: AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.itemSpacing),
                        Expanded(
                          child: AppStatCard(
                            title: AppStrings.loansRemaining,
                            value: AppFormatters.amount(
                              state.activeRemainingAmount,
                            ),
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: AppColors.warning,
                            iconBackground: AppColors.warningLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.itemSpacing),

                    // تصفية الحالة
                    Wrap(
                      spacing: AppDimensions.spacing8,
                      children: [
                        FilterChip(
                          label: const Text(AppStrings.all),
                          selected: state.filterStatus == null,
                          onSelected: (_) => context
                              .read<EmployeeLoansBloc>()
                              .add(const EmployeeLoansLoadRequested()),
                        ),
                        FilterChip(
                          label: const Text('نشطة'),
                          selected: state.filterStatus == AppStatuses.active,
                          onSelected: (_) => context
                              .read<EmployeeLoansBloc>()
                              .add(const EmployeeLoansLoadRequested(
                                status: AppStatuses.active,
                              )),
                        ),
                        FilterChip(
                          label: const Text('مسددة'),
                          selected: state.filterStatus == AppStatuses.paidOff,
                          onSelected: (_) => context
                              .read<EmployeeLoansBloc>()
                              .add(const EmployeeLoansLoadRequested(
                                status: AppStatuses.paidOff,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.itemSpacing),

                    // القائمة
                    Expanded(
                      child: _LoansList(
                        state: state,
                        onTapLoan: (loan) => context.go('/loans/${loan.id}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoansList extends StatelessWidget {
  const _LoansList({required this.state, required this.onTapLoan});

  final EmployeeLoansState state;
  final void Function(EmployeeLoanEntity) onTapLoan;

  @override
  Widget build(BuildContext context) {
    if (state.status == EmployeeLoansStatus.loading && state.loans.isEmpty) {
      return const AppLoadingView(message: AppStrings.loading);
    }

    if (state.status == EmployeeLoansStatus.failure && state.loans.isEmpty) {
      return AppErrorView(
        message: state.failure?.message ?? AppStrings.errorGeneric,
        onRetry: () => context
            .read<EmployeeLoansBloc>()
            .add(EmployeeLoansLoadRequested(status: state.filterStatus)),
      );
    }

    final loans = state.visibleLoans;
    if (loans.isEmpty) {
      return const AppEmptyView(
        message: 'لا توجد سلف مطابقة',
        icon: Icons.handshake_outlined,
      );
    }

    return ListView.separated(
      itemCount: loans.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.itemSpacing),
      itemBuilder: (context, index) => _LoanCard(
        loan: loans[index],
        onTap: () => onTapLoan(loans[index]),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan, required this.onTap});

  final EmployeeLoanEntity loan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = loan.isActive;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  loan.employeeName,
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              AppStatusChip(
                label: isActive
                    ? AppStrings.statusActive
                    : AppStrings.statusPaidOff,
                color: isActive ? AppColors.success : AppColors.info,
                backgroundColor:
                    isActive ? AppColors.successLight : AppColors.infoLight,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing8),
          AppInfoRow(
            label: 'الإجمالي',
            value: AppFormatters.amount(loan.totalAmount),
          ),
          AppInfoRow(
            label: 'المتبقي',
            value: AppFormatters.amount(loan.remainingBalance),
            valueColor:
                isActive ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          const SizedBox(height: AppDimensions.spacing8),
          // شريط تقدم نسبة السداد
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: loan.paidRatio,
                  minHeight: AppDimensions.bottomSheetHandleHeight + 2,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.success),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSmall),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Text(
                AppFormatters.percent(loan.paidRatio),
                style: AppTypography.labelMedium,
              ),
            ],
          ),
          if (loan.notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacing4),
            Text(
              loan.notes,
              style: AppTypography.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
