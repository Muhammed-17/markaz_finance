import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_centers_finance/core/widgets/app_amount_text.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../transactions/presentation/widgets/month_field.dart'
    show categoryLabel;
import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../bloc/envelopes_bloc.dart';
import 'envelope_form_sheet.dart';
import 'envelope_reconciliation_dialog.dart';
import 'envelope_transfer_sheet.dart';

/// صفحة الأظرف المالية: بطاقات الأظرف النشطة والمؤرشفة مع الإجراءات.
class EnvelopesPage extends StatefulWidget {
  const EnvelopesPage({super.key});

  @override
  State<EnvelopesPage> createState() => _EnvelopesPageState();
}

class _EnvelopesPageState extends State<EnvelopesPage> {
  bool _showArchived = false;
  late final EnvelopesBloc _envelopesBloc;

  /// هل توجد نافذة سفلية مفتوحة الآن؟ (لإغلاقها عند نجاح العملية فقط)
  bool _isSheetOpen = false;
  NavigatorState? _openSheetNavigator;

  UserProfileEntity? get _currentProfile {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.profile : null;
  }

  bool get _canCreate =>
      PermissionService.can(_currentProfile, PermissionAction.create);

  bool get _canUpdate =>
      PermissionService.can(_currentProfile, PermissionAction.update);

  bool get _isAdmin => _currentProfile?.role == 'admin';

  @override
  void initState() {
    super.initState();
    _envelopesBloc = sl<EnvelopesBloc>()..add(const EnvelopesLoadRequested());
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
        // احتفظ بملاح النافذة نفسها؛ لا تستخدم سياق الصفحة عند الإغلاق
        // حتى لا يُغلق مسار الأظرف ويظهر فراغ/شاشة سوداء.
        _openSheetNavigator = Navigator.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
          clipBehavior: Clip.antiAlias,
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
          ? 'سيتم أرشفة الظرف "${envelope.name}" ولن يظهر ضمن خيارات الحركات '
              'والنماذج الجديدة. لا يمكن أرشفة ظرف به رصيد غير صفري — '
              'حوّل الرصيد أولًا إن وُجد. هل تريد المتابعة؟'
          : 'سيتم إعادة تنشيط الظرف "${envelope.name}" ليصبح متاحًا '
              'للحركات والنماذج من جديد. هل تريد المتابعة؟',
      confirmLabel: archiving ? 'أرشفة' : 'إعادة تنشيط',
      isDanger: archiving,
    );
    if (!confirmed || !mounted) return;
    _envelopesBloc.add(EnvelopesArchiveRequested(
      envelopeId: envelope.id,
      archive: archiving,
    ));
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
              isError: state.status == EnvelopesStatus.operationFailure,
            );
          }
          // إغلاق النافذة السفلية بعد نجاح العملية فقط (لا يوجد نجاح إلا من الخادم).
          if (state.status == EnvelopesStatus.operationCompleted &&
              _isSheetOpen) {
            _openSheetNavigator?.pop();
            setState(() => _isSheetOpen = false);
          }
        },
        builder: (context, state) {
          final envelopes = state.visibleEnvelopes(showArchived: _showArchived);
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
                            hintText: 'ابحث باسم الظرف أو الغرض...',
                            prefixIcon: Icons.search_rounded,
                            onChanged: (v) => context
                                .read<EnvelopesBloc>()
                                .add(EnvelopesSearchQueryChanged(v)),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacing12),
                        if (_canCreate) ...[
                          AppButton(
                            label: 'إضافة ظرف',
                            icon: Icons.add_rounded,
                            isFullWidth: false,
                            onPressed: () => _openFormSheet(),
                          ),
                          const SizedBox(width: AppDimensions.spacing8),
                          AppButton(
                            label: 'تحويل بين الأظرف',
                            icon: Icons.swap_horiz_rounded,
                            isFullWidth: false,
                            variant: AppButtonVariant.secondary,
                            onPressed: state.activeEnvelopes.length >= 2
                                ? _openTransferSheet
                                : null,
                          ),
                        ],
                        if (_isAdmin) ...[
                          const SizedBox(width: AppDimensions.spacing8),
                          AppButton(
                            label: 'مطابقة الأرصدة',
                            icon: Icons.fact_check_outlined,
                            isFullWidth: false,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => const EnvelopeReconciliationDialog(),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppDimensions.itemSpacing),

                    // تبويب النشطة/المؤرشفة
                    Wrap(
                      spacing: AppDimensions.spacing8,
                      children: [
                        FilterChip(
                          label: const Text('النشطة'),
                          selected: !_showArchived,
                          onSelected: (_) =>
                              setState(() => _showArchived = false),
                        ),
                        FilterChip(
                          label: const Text('المؤرشفة'),
                          selected: _showArchived,
                          onSelected: (_) =>
                              setState(() => _showArchived = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.itemSpacing),

                    // القائمة
                    Expanded(
                        child: _EnvelopesList(
                      state: state,
                      envelopes: envelopes,
                      showArchived: _showArchived,
                      canUpdate: _canUpdate,
                      onEdit: (envelope) => _openFormSheet(envelope: envelope),
                      onArchive: _confirmArchive,
                    )),
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
  final void Function(EnvelopeEntity) onEdit;
  final void Function(EnvelopeEntity) onArchive;

  @override
  Widget build(BuildContext context) {
    if (state.status == EnvelopesStatus.loading && state.items.isEmpty) {
      return const AppLoadingView(message: AppStrings.loading);
    }

    if (state.status == EnvelopesStatus.failure && state.items.isEmpty) {
      return AppErrorView(
        message: state.failure?.message ?? AppStrings.errorGeneric,
        onRetry: () =>
            context.read<EnvelopesBloc>().add(const EnvelopesLoadRequested()),
      );
    }

    if (envelopes.isEmpty) {
      return AppEmptyView(
        message: showArchived
            ? 'لا توجد أظرف مؤرشفة'
            : 'لا توجد أظرف نشطة مطابقة — أنشئ ظرفًا جديدًا لتنظيم الأموال',
        icon: Icons.account_balance_wallet_outlined,
      );
    }

    return ListView.separated(
      itemCount: envelopes.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.itemSpacing),
      itemBuilder: (context, index) => _EnvelopeCard(
        envelope: envelopes[index],
        canUpdate: canUpdate,
        onEdit: () => onEdit(envelopes[index]),
        onArchive: () => onArchive(envelopes[index]),
      ),
    );
  }
}

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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // الاسم + شريحة النوع + الرصيد
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  envelope.name,
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              AppStatusChip(
                label: isGeneral ? 'عام' : 'مخصص',
                color: isGeneral ? AppColors.info : AppColors.warning,
                backgroundColor:
                    isGeneral ? AppColors.infoLight : AppColors.warningLight,
              ),
              const SizedBox(width: AppDimensions.spacing12),
              AppNeutralAmountText(
                amount: envelope.currentBalance,
                style: AppTypography.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing4),

          // الغرض المختصر
          Text(
            envelope.purpose,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.spacing8),

          // التصنيفات المسموحة
          if (isGeneral)
            const Text(
              'يقبل كل تصنيفات المصروفات',
              style: AppTypography.labelSmall,
            )
          else if (envelope.allowedExpenseCategories.isEmpty)
            Text(
              'لا توجد تصنيفات مسموحة محددة',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.warning,
              ),
            )
          else
            Wrap(
              spacing: AppDimensions.spacing4,
              runSpacing: AppDimensions.spacing4,
              children: envelope.allowedExpenseCategories
                  .map(
                    (category) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing8,
                        vertical: AppDimensions.spacing2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall,
                        ),
                      ),
                      child: Text(
                        categoryLabel(category),
                        style: AppTypography.labelSmall,
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: AppDimensions.spacing8),

          // التاريخ + الإجراءات
          Row(
            children: [
              Text(
                'أُنشئ: ${AppFormatters.date(envelope.createdAt)}',
                style: AppTypography.labelSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.go(
                  '/envelopes/${envelope.id}/transactions',
                ),
                icon: const Icon(Icons.receipt_long_outlined,
                    size: AppDimensions.iconSmall + 2),
                label: const Text('سجل الحركات'),
              ),
              if (!envelope.isArchived) ...[
                const SizedBox(width: AppDimensions.spacing4),
                TextButton.icon(
                  onPressed: canUpdate ? onEdit : null,
                  icon: const Icon(Icons.edit_outlined,
                      size: AppDimensions.iconSmall + 2),
                  label: const Text(AppStrings.edit),
                ),
              ],
              if (canUpdate)
                TextButton.icon(
                  onPressed: onArchive,
                  icon: Icon(
                    envelope.isActive
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                    size: AppDimensions.iconSmall + 2,
                  ),
                  label: Text(envelope.isActive ? 'أرشفة' : 'إعادة تنشيط'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        envelope.isActive ? AppColors.error : AppColors.success,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
