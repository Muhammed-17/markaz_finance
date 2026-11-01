import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
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
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../transactions/presentation/widgets/month_field.dart'
    show categoryLabel;
import '../bloc/envelopes_bloc.dart';
import 'envelope_form_sheet.dart';
import 'envelope_reconciliation_dialog.dart';
import 'envelope_transfer_sheet.dart';

class EnvelopesPage extends StatefulWidget {
  const EnvelopesPage({super.key});

  @override
  State<EnvelopesPage> createState() => _EnvelopesPageState();
}

class _EnvelopesPageState extends State<EnvelopesPage> {
  bool _showArchived = false;

  late final EnvelopesBloc _envelopesBloc;

  bool _isSheetOpen = false;
  NavigatorState? _openSheetNavigator;

  UserProfileEntity? get _currentProfile {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.profile : null;
  }

  bool get _canCreate =>
      PermissionService.isAdmin(_currentProfile);

  bool get _canUpdate =>
      PermissionService.isAdmin(_currentProfile);

  bool get _isAdmin => _currentProfile?.role == 'admin';

  @override
  void initState() {
    super.initState();
    _envelopesBloc = sl<EnvelopesBloc>()
      ..add(const EnvelopesLoadRequested());
  }

  @override
  void dispose() {
    _envelopesBloc.close();
    super.dispose();
  }

  Future<void> _openFormSheet({EnvelopeEntity? envelope}) async {
    setState(() => _isSheetOpen = true);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _openSheetNavigator = Navigator.of(dialogContext);

        return Dialog(
          insetPadding: const EdgeInsets.all(
            AppDimensions.pagePaddingMobile,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppDimensions.radiusLarge,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: BlocProvider<EnvelopesBloc>.value(
              value: _envelopesBloc,
              child: EnvelopeFormSheet(envelope: envelope),
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _isSheetOpen = false);
      _openSheetNavigator = null;
    }
  }

  Future<void> _openTransferSheet() async {
    setState(() => _isSheetOpen = true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLarge),
        ),
      ),
      builder: (sheetContext) {
        _openSheetNavigator = Navigator.of(sheetContext);

        return BlocProvider<EnvelopesBloc>.value(
          value: _envelopesBloc,
          child: const EnvelopeTransferSheet(),
        );
      },
    );

    if (mounted) {
      setState(() => _isSheetOpen = false);
      _openSheetNavigator = null;
    }
  }

  Future<void> _confirmArchive(EnvelopeEntity envelope) async {
    final archiving = envelope.isActive;

    final confirmed = await showAppConfirmDialog(
      context,
      title: archiving ? 'أرشفة الظرف' : 'إعادة تنشيط الظرف',
      message: archiving
          ? 'سيتم أرشفة الظرف "${envelope.name}" ولن يظهر ضمن خيارات '
              'الحركات الجديدة. لا يمكن أرشفة ظرف له رصيد غير صفري؛ '
              'حوّل الرصيد أولًا إن وُجد. هل تريد المتابعة؟'
          : 'سيتم إعادة تنشيط الظرف "${envelope.name}" ليصبح متاحًا '
              'للحركات الجديدة. هل تريد المتابعة؟',
      confirmLabel: archiving ? 'أرشفة' : 'إعادة تنشيط',
      isDanger: archiving,
    );

    if (!confirmed || !mounted) return;

    _envelopesBloc.add(
      EnvelopesArchiveRequested(
        envelopeId: envelope.id,
        archive: archiving,
      ),
    );
  }

  void _openReconciliationDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const EnvelopeReconciliationDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _envelopesBloc,
      child: BlocConsumer<EnvelopesBloc, EnvelopesState>(
        listener: (context, state) {
          final message = state.message;

          if (message != null) {
            showAppSnackBar(
              context,
              message: message,
              isError:
                  state.status == EnvelopesStatus.operationFailure,
            );
          }

          if (state.status == EnvelopesStatus.operationCompleted &&
              _isSheetOpen) {
            _openSheetNavigator?.pop();

            if (mounted) {
              setState(() => _isSheetOpen = false);
            }
          }
        },
        builder: (context, state) {
          final envelopes = state.visibleEnvelopes(
            showArchived: _showArchived,
          );

          return ColoredBox(
            color: AppColors.background,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding =
                    constraints.maxWidth >=
                            AppDimensions.tabletBreakpoint
                        ? AppDimensions.pagePaddingDesktop
                        : AppDimensions.pagePaddingMobile;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: AppDimensions.spacing12,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppDimensions.maxContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _EnvelopesHeader(
                            activeCount:
                                state.activeEnvelopes.length,
                            archived: _showArchived,
                          ),
                          const SizedBox(
                            height: AppDimensions.spacing12,
                          ),
                          _EnvelopesToolbar(
                            canCreate: _canCreate,
                            isAdmin: _isAdmin,
                            activeEnvelopeCount:
                                state.activeEnvelopes.length,
                            onAdd: () => _openFormSheet(),
                            onTransfer: _openTransferSheet,
                            onReconciliation:
                                _openReconciliationDialog,
                          ),
                          const SizedBox(
                            height: AppDimensions.spacing12,
                          ),
                          _EnvelopeFilters(
                            showArchived: _showArchived,
                            activeCount:
                                state.activeEnvelopes.length,
                            archivedCount: state.items
                                .where((item) => item.isArchived)
                                .length,
                            onChanged: (value) {
                              setState(
                                () => _showArchived = value,
                              );
                            },
                          ),
                          const SizedBox(
                            height: AppDimensions.spacing12,
                          ),
                          _EnvelopesList(
                            state: state,
                            envelopes: envelopes,
                            showArchived: _showArchived,
                            canUpdate: _canUpdate,
                            onEdit: (envelope) =>
                                _openFormSheet(
                                  envelope: envelope,
                                ),
                            onArchive: _confirmArchive,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// رأس الصفحة
// -----------------------------------------------------------------------------

class _EnvelopesHeader extends StatelessWidget {
  const _EnvelopesHeader({
    required this.activeCount,
    required this.archived,
  });

  final int activeCount;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppDimensions.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          AppDimensions.radiusLarge,
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(
                AppDimensions.radiusMedium,
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              size: AppDimensions.iconLarge,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'إدارة الأظرف المالية',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Text(
                  archived
                      ? 'الأظرف المؤرشفة'
                      : 'تنظيم الأموال ومتابعة الأرصدة',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing12,
              vertical: AppDimensions.spacing8,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(
                AppDimensions.radiusMedium,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$activeCount',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'نشط',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// شريط الإجراءات
// -----------------------------------------------------------------------------

class _EnvelopesToolbar extends StatelessWidget {
  const _EnvelopesToolbar({
    required this.canCreate,
    required this.isAdmin,
    required this.activeEnvelopeCount,
    required this.onAdd,
    required this.onTransfer,
    required this.onReconciliation,
  });

  final bool canCreate;
  final bool isAdmin;
  final int activeEnvelopeCount;
  final VoidCallback onAdd;
  final VoidCallback onTransfer;
  final VoidCallback onReconciliation;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: AppDimensions.iconMedium,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  Expanded(
                    child: Text(
                      'إجراءات الأظرف',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing12),
              Wrap(
                spacing: AppDimensions.spacing8,
                runSpacing: AppDimensions.spacing8,
                children: [
                  if (canCreate)
                    AppButton(
                      label: 'إضافة ظرف',
                      icon: Icons.add_rounded,
                      isFullWidth: false,
                      onPressed: onAdd,
                    ),
                  if (canCreate)
                    _SecondaryAction(
                      label: 'تحويل بين الأظرف',
                      icon: Icons.swap_horiz_rounded,
                      onPressed: activeEnvelopeCount >= 2
                          ? onTransfer
                          : null,
                      compact: compact,
                    ),
                  if (isAdmin)
                    _SecondaryAction(
                      label: 'مطابقة الأرصدة',
                      icon: Icons.fact_check_outlined,
                      onPressed: onReconciliation,
                      compact: compact,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: AppDimensions.iconSmall + 2,
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.disabled,
        side: const BorderSide(color: AppColors.border),
        minimumSize: Size(
          compact ? 0 : 160,
          AppDimensions.buttonHeight,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing12,
          vertical: AppDimensions.spacing8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppDimensions.radiusMedium,
          ),
        ),
        textStyle: AppTypography.labelMedium.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// البحث والفلاتر
// -----------------------------------------------------------------------------

class _EnvelopeFilters extends StatelessWidget {
  const _EnvelopeFilters({
    required this.showArchived,
    required this.activeCount,
    required this.archivedCount,
    required this.onChanged,
  });

  final bool showArchived;
  final int activeCount;
  final int archivedCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: AppStrings.search,
            hintText: 'ابحث باسم الظرف أو الغرض...',
            prefixIcon: Icons.search_rounded,
            onChanged: (value) {
              context
                  .read<EnvelopesBloc>()
                  .add(EnvelopesSearchQueryChanged(value));
            },
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              Text(
                'عرض:',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _FilterChip(
                label: 'النشطة',
                count: activeCount,
                selected: !showArchived,
                onTap: () => onChanged(false),
              ),
              _FilterChip(
                label: 'المؤرشفة',
                count: archivedCount,
                selected: showArchived,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryLight
          : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(
        AppDimensions.radiusMedium,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppDimensions.radiusMedium,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12,
            vertical: AppDimensions.spacing8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              AppDimensions.radiusMedium,
            ),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing4,
                  vertical: AppDimensions.spacing2,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.labelSmall.copyWith(
                    color: selected
                        ? AppColors.textOnPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// قائمة الأظرف: لا يوجد تمرير داخلي
// -----------------------------------------------------------------------------

class _EnvelopesList extends StatelessWidget {
  const _EnvelopesList({
    required this.state,
    required this.envelopes,
    required this.showArchived,
    required this.canUpdate,
    required this.onEdit,
    required this.onArchive,
  });

  final EnvelopesState state;
  final List<EnvelopeEntity> envelopes;
  final bool showArchived;
  final bool canUpdate;
  final ValueChanged<EnvelopeEntity> onEdit;
  final ValueChanged<EnvelopeEntity> onArchive;

  @override
  Widget build(BuildContext context) {
    if (state.status == EnvelopesStatus.loading &&
        state.items.isEmpty) {
      return const AppLoadingView(
        message: AppStrings.loading,
      );
    }

    if (state.status == EnvelopesStatus.failure &&
        state.items.isEmpty) {
      return AppErrorView(
        message: state.failure?.message ??
            AppStrings.errorGeneric,
        onRetry: () {
          context
              .read<EnvelopesBloc>()
              .add(const EnvelopesLoadRequested());
        },
      );
    }

    if (envelopes.isEmpty) {
      return _EmptyEnvelopes(
        showArchived: showArchived,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 850;

        if (useGrid) {
          final crossAxisCount =
              constraints.maxWidth >= 1200 ? 3 : 2;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              bottom: AppDimensions.spacing16,
            ),
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppDimensions.spacing12,
              mainAxisSpacing: AppDimensions.spacing12,
              mainAxisExtent: 290,
            ),
            itemCount: envelopes.length,
            itemBuilder: (context, index) {
              final envelope = envelopes[index];

              return _EnvelopeCard(
                envelope: envelope,
                canUpdate: canUpdate,
                onEdit: () => onEdit(envelope),
                onArchive: () => onArchive(envelope),
              );
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.only(
            bottom: AppDimensions.spacing16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0;
                  index < envelopes.length;
                  index++) ...[
                if (index > 0)
                  const SizedBox(
                    height: AppDimensions.spacing12,
                  ),
                _EnvelopeCard(
                  envelope: envelopes[index],
                  canUpdate: canUpdate,
                  onEdit: () => onEdit(envelopes[index]),
                  onArchive: () => onArchive(envelopes[index]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// الحالة الفارغة
// -----------------------------------------------------------------------------

class _EmptyEnvelopes extends StatelessWidget {
  const _EmptyEnvelopes({
    required this.showArchived,
  });

  final bool showArchived;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusLarge,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                  size: AppDimensions.iconLarge,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing12),
              Text(
                showArchived
                    ? 'لا توجد أظرف مؤرشفة'
                    : 'لا توجد أظرف نشطة',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                showArchived
                    ? 'ستظهر هنا الأظرف التي تمت أرشفتها.'
                    : 'أنشئ أظرفًا لتنظيم الأموال وتخصيصها للأغراض المختلفة.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// بطاقة الظرف
// -----------------------------------------------------------------------------

class _EnvelopeCard extends StatelessWidget {
  const _EnvelopeCard({
    required this.envelope,
    required this.canUpdate,
    required this.onEdit,
    required this.onArchive,
  });

  final EnvelopeEntity envelope;
  final bool canUpdate;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final isGeneral = envelope.isGeneral;
    final isArchived = envelope.isArchived;

    final typeColor =
        isGeneral ? AppColors.info : AppColors.warning;
    final typeBackground =
        isGeneral ? AppColors.infoLight : AppColors.warningLight;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isArchived
                      ? AppColors.surfaceAlt
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                ),
                child: Icon(
                  isGeneral
                      ? Icons.account_balance_wallet_outlined
                      : Icons.savings_outlined,
                  color: isArchived
                      ? AppColors.textSecondary
                      : AppColors.primary,
                  size: AppDimensions.iconMedium,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      envelope.name,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacing4),
                    Wrap(
                      spacing: AppDimensions.spacing4,
                      runSpacing: AppDimensions.spacing4,
                      children: [
                        _EnvelopeBadge(
                          label: isGeneral ? 'عام' : 'مخصص',
                          color: typeColor,
                          backgroundColor: typeBackground,
                        ),
                        if (isArchived)
                          const _EnvelopeBadge(
                            label: 'مؤرشف',
                            color: AppColors.textSecondary,
                            backgroundColor: AppColors.surfaceAlt,
                          )
                        else if (envelope.isActive)
                          const _EnvelopeBadge(
                            label: 'نشط',
                            color: AppColors.success,
                            backgroundColor: AppColors.successLight,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing12),

          // الرصيد
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing12,
              vertical: AppDimensions.spacing8,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(
                AppDimensions.radiusMedium,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_outlined,
                  color: AppColors.primary,
                  size: AppDimensions.iconMedium,
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    'الرصيد الحالي',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                AppNeutralAmountText(
                  amount: envelope.currentBalance,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spacing12),

          // الغرض
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notes_rounded,
                size: AppDimensions.iconSmall,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(
                  envelope.purpose.trim().isEmpty
                      ? 'لم يُحدد غرض لهذا الظرف'
                      : envelope.purpose,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // التصنيفات
          if (isGeneral) ...[
            const SizedBox(height: AppDimensions.spacing8),
            const _EnvelopeBadge(
              label: 'يقبل جميع تصنيفات المصروفات',
              color: AppColors.info,
              backgroundColor: AppColors.infoLight,
            ),
          ] else if (
              envelope.allowedExpenseCategories.isNotEmpty
          ) ...[
            const SizedBox(height: AppDimensions.spacing8),
            Wrap(
              spacing: AppDimensions.spacing4,
              runSpacing: AppDimensions.spacing4,
              children: envelope.allowedExpenseCategories
                  .take(3)
                  .map(
                    (category) => _EnvelopeBadge(
                      label: categoryLabel(category),
                      color: AppColors.textSecondary,
                      backgroundColor: AppColors.surfaceAlt,
                    ),
                  )
                  .toList(),
            ),
            if (envelope.allowedExpenseCategories.length > 3)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppDimensions.spacing4,
                ),
                child: Text(
                  '+${envelope.allowedExpenseCategories.length - 3} تصنيفات أخرى',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: AppDimensions.spacing8),
            Text(
              'لا توجد تصنيفات مصروفات مسموحة محددة',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.spacing8),

          // تاريخ الإنشاء
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: AppDimensions.iconSmall,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.spacing4),
              Expanded(
                child: Text(
                  AppFormatters.date(envelope.createdAt),
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacing4),
          const Divider(
            height: 1,
            color: AppColors.border,
          ),

          // الإجراءات
          Wrap(
            spacing: AppDimensions.spacing4,
            runSpacing: 0,
            children: [
              TextButton.icon(
                onPressed: () {
                  context.go(
                    '/envelopes/${envelope.id}/transactions',
                  );
                },
                icon: const Icon(
                  Icons.receipt_long_outlined,
                  size: AppDimensions.iconSmall,
                ),
                label: const Text('الحركات'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing8,
                  ),
                  textStyle: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isArchived)
                TextButton.icon(
                  onPressed: canUpdate ? onEdit : null,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: AppDimensions.iconSmall,
                  ),
                  label: const Text('تعديل'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing8,
                    ),
                    textStyle: AppTypography.labelSmall,
                  ),
                ),
              if (canUpdate)
                TextButton.icon(
                  onPressed: onArchive,
                  icon: Icon(
                    envelope.isActive
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                    size: AppDimensions.iconSmall,
                  ),
                  label: Text(
                    envelope.isActive ? 'أرشفة' : 'تنشيط',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: envelope.isActive
                        ? AppColors.error
                        : AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing8,
                    ),
                    textStyle: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// شارة الظرف
// -----------------------------------------------------------------------------

class _EnvelopeBadge extends StatelessWidget {
  const _EnvelopeBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing8,
        vertical: AppDimensions.spacing4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          AppDimensions.radiusSmall,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
