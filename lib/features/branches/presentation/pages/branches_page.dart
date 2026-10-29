import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/branch_entity.dart';
import '../../domain/usecases/branches_usecases.dart';
import '../bloc/branches_bloc.dart';
import 'branch_details_sheet.dart';
import 'branch_form_sheet.dart';

/// صفحة الفروع: قائمة الفروع مع فلتر المركز والبحث المحلي والإضافة والتعديل.
///
/// الصفحة تنشئ Bloc الخاص بها عبر حاوية الاعتماديات (registerFactory)
/// فلا حاجة لتغليف المسار بـ BlocProvider من الراوتر.
class BranchesPage extends StatelessWidget {
  const BranchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BranchesBloc>(
      create: (_) => sl<BranchesBloc>()..add(const BranchesLoadRequested()),
      child: const _BranchesView(),
    );
  }
}

class _BranchesView extends StatefulWidget {
  const _BranchesView();

  @override
  State<_BranchesView> createState() => _BranchesViewState();
}

class _BranchesViewState extends State<_BranchesView> {
  final TextEditingController _searchController = TextEditingController();
  late final LoadCenterOptions _loadCenterOptions;

  List<CenterRef> _centerOptions = const [];
  bool _centersLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadCenterOptions = sl<LoadCenterOptions>();
    _loadCenters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// تحميل قائمة المراكز المرجعية عبر حالة الاستخدام (قراءة فقط).
  Future<void> _loadCenters() async {
    final result = await _loadCenterOptions();
    if (!mounted) return;
    setState(() {
      _centersLoadFailed = result.isLeft();
      _centerOptions = result.fold((_) => _centerOptions, (centers) => centers);
    });
    if (_centersLoadFailed) {
      showAppSnackBar(
        context,
        message: 'تعذر تحميل قائمة المراكز — تحقق من اتصالك',
        isError: true,
      );
    }
  }

  String? _centerNameFor(String centerId) {
    for (final center in _centerOptions) {
      if (center.id == centerId) return center.name;
    }
    return null;
  }

  void _onSearchChanged(String query) {
    context.read<BranchesBloc>().add(BranchesSearchQueryChanged(query));
  }

  Future<void> _openForm(
    BuildContext context, {
    BranchEntity? branch,
    String? initialCenterId,
  }) {
    final bloc = context.read<BranchesBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusExtraLarge),
        ),
      ),
      builder: (sheetContext) => BlocProvider<BranchesBloc>.value(
        value: bloc,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: BranchFormSheet(
            branch: branch,
            initialCenterId: initialCenterId,
            centers: _centerOptions,
          ),
        ),
      ),
    );
  }

  Future<void> _openDetails(
    BuildContext context, {
    required BranchEntity branch,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusExtraLarge),
        ),
      ),
      builder: (sheetContext) => BranchDetailsSheet(
        branch: branch,
        centerName: _centerNameFor(branch.centerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BranchesBloc, BranchesState>(
      listener: (context, state) {
        final message = state.message;
        if (message != null &&
            (state.status == BranchesStatus.operationCompleted ||
                state.status == BranchesStatus.operationFailure)) {
          showAppSnackBar(
            context,
            message: message,
            isError: state.status == BranchesStatus.operationFailure,
          );
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // شريط الأدوات: بحث + إضافة فرع
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: AppStrings.search,
                      controller: _searchController,
                      hintText: 'ابحث باسم الفرع...',
                      prefixIcon: Icons.search_rounded,
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  AppButton(
                    label: 'إضافة فرع',
                    icon: Icons.add_rounded,
                    isFullWidth: false,
                    onPressed: () => _openForm(context),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.itemSpacing),

              // فلتر المركز
              _buildCenterFilter(context, state),
              const SizedBox(height: AppDimensions.itemSpacing),

              // تنبيه البيانات المخزنة مؤقتًا
              if (state.isStale) ...[
                const _StaleBanner(),
                const SizedBox(height: AppDimensions.itemSpacing),
              ],

              Expanded(child: _buildBody(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCenterFilter(BuildContext context, BranchesState state) {
    if (_centerOptions.isEmpty) {
      final isFailure = _centersLoadFailed;
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spacing12),
        decoration: BoxDecoration(
          color: isFailure ? AppColors.errorLight : AppColors.infoLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border:
              Border.all(color: isFailure ? AppColors.error : AppColors.info),
        ),
        child: Row(
          children: [
            Icon(
              isFailure
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              color: isFailure ? AppColors.error : AppColors.info,
              size: AppDimensions.iconMedium,
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Text(
                isFailure
                    ? 'تعذر تحميل قائمة المراكز'
                    : 'لا توجد مراكز مسجلة — أضف مركزًا من شاشة المراكز أولًا',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isFailure)
              TextButton.icon(
                onPressed: _loadCenters,
                icon: const Icon(Icons.refresh_rounded,
                    size: AppDimensions.iconMedium),
                label: const Text(AppStrings.retry),
              ),
          ],
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 280,
          child: AppDropdownField<String>(
            label: 'تصفية حسب المركز',
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text(AppStrings.all),
              ),
              ..._centerOptions.map(
                (center) => DropdownMenuItem<String>(
                  value: center.id,
                  child: Text(center.name),
                ),
              ),
            ],
            value: state.selectedCenterId,
            hint: AppStrings.all,
            onChanged: (value) => context.read<BranchesBloc>().add(
                  BranchesCenterFilterChanged(
                    (value == null || value.isEmpty) ? null : value,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, BranchesState state) {
    if (state.status == BranchesStatus.loading && state.items.isEmpty) {
      return const AppLoadingView(message: AppStrings.loading);
    }

    if (state.status == BranchesStatus.failure && state.items.isEmpty) {
      return AppErrorView(
        message: state.failure?.message ?? AppStrings.errorGeneric,
        onRetry: () =>
            context.read<BranchesBloc>().add(const BranchesLoadRequested()),
      );
    }

    final visible = state.filteredItems;
    if (visible.isEmpty) {
      final isSearching = state.searchQuery.trim().isNotEmpty;
      if (state.items.isNotEmpty && isSearching) {
        return const AppEmptyView(
          message: 'لا توجد فروع مطابقة لبحثك',
          icon: Icons.search_off_rounded,
        );
      }
      return AppEmptyView(
        message: 'لا توجد فروع مسجلة بعد',
        icon: Icons.location_city_outlined,
        actionLabel: 'إضافة فرع',
        onAction: () => _openForm(
          context,
          initialCenterId: state.selectedCenterId,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          context.read<BranchesBloc>().add(const BranchesLoadRequested()),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppDimensions.spacing24),
        itemCount: visible.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppDimensions.itemSpacing),
        itemBuilder: (itemContext, index) {
          final branch = visible[index];
          return _BranchCard(
            branch: branch,
            centerName: _centerNameFor(branch.centerId),
            onEdit: () => _openForm(itemContext, branch: branch),
            onDetails: () => _openDetails(itemContext, branch: branch),
          );
        },
      ),
    );
  }
}

/// بطاقة فرع واحدة: أيقونة + الاسم + الموقع + المركز + قائمة منبثقة.
class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.onEdit,
    required this.onDetails,
    this.centerName,
  });

  final BranchEntity branch;
  final String? centerName;
  final VoidCallback onEdit;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onDetails,
      child: Row(
        children: [
          Container(
            width: AppDimensions.iconLarge + AppDimensions.spacing8,
            height: AppDimensions.iconLarge + AppDimensions.spacing8,
            decoration: BoxDecoration(
              color: AppColors.secondaryLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: const Icon(
              Icons.location_city_rounded,
              color: AppColors.secondary,
              size: AppDimensions.iconMedium + 2,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  branch.name,
                  style: AppTypography.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (branch.location.trim().isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacing4),
                  Text(
                    branch.location,
                    style: AppTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (centerName != null && centerName!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacing2),
                  Text(
                    '${AppStrings.center}: $centerName',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'details') onDetails();
            },
            itemBuilder: (menuContext) => const [
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: AppDimensions.iconSmall,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: AppDimensions.spacing8),
                    Text(AppStrings.edit),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'details',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: AppDimensions.iconSmall,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: AppDimensions.spacing8),
                    Text(AppStrings.details),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// شريط تنبيه بأن البيانات المعروضة قادمة من التخزين المؤقت.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.warning,
            size: AppDimensions.iconMedium,
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Text(
              AppStrings.cachedDataWarning,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
