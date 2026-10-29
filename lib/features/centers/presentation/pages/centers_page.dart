import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/center_entity.dart';
import '../bloc/centers_bloc.dart';
import 'center_details_sheet.dart';
import 'center_form_sheet.dart';

/// صفحة المراكز: قائمة المراكز مع البحث المحلي والإضافة والتعديل.
///
/// الصفحة تنشئ Bloc الخاص بها عبر حاوية الاعتماديات (registerFactory)
/// فلا حاجة لتغليف المسار بـ BlocProvider من الراوتر.
class CentersPage extends StatelessWidget {
  const CentersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CentersBloc>(
      create: (_) => sl<CentersBloc>()..add(const CentersLoadRequested()),
      child: const _CentersView(),
    );
  }
}

class _CentersView extends StatefulWidget {
  const _CentersView();

  @override
  State<_CentersView> createState() => _CentersViewState();
}

class _CentersViewState extends State<_CentersView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<CentersBloc>().add(CentersSearchQueryChanged(query));
  }

  Future<void> _openForm(BuildContext context, {CenterEntity? center}) {
    final bloc = context.read<CentersBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusExtraLarge),
        ),
      ),
      builder: (sheetContext) => BlocProvider<CentersBloc>.value(
        value: bloc,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: CenterFormSheet(center: center),
        ),
      ),
    );
  }

  Future<void> _openDetails(BuildContext context,
      {required CenterEntity center}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusExtraLarge),
        ),
      ),
      builder: (sheetContext) => CenterDetailsSheet(center: center),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CentersBloc, CentersState>(
      listener: (context, state) {
        final message = state.message;
        if (message != null &&
            (state.status == CentersStatus.operationCompleted ||
                state.status == CentersStatus.operationFailure)) {
          showAppSnackBar(
            context,
            message: message,
            isError: state.status == CentersStatus.operationFailure,
          );
        }
      },
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // شريط الأدوات: بحث + إضافة مركز
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: AppStrings.search,
                      controller: _searchController,
                      hintText: 'ابحث باسم المركز...',
                      prefixIcon: Icons.search_rounded,
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing8),
                  AppButton(
                    label: 'إضافة مركز',
                    icon: Icons.add_rounded,
                    isFullWidth: false,
                    onPressed: () => _openForm(context),
                  ),
                ],
              ),
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

  Widget _buildBody(BuildContext context, CentersState state) {
    if (state.status == CentersStatus.loading && state.items.isEmpty) {
      return const AppLoadingView(message: AppStrings.loading);
    }

    if (state.status == CentersStatus.failure && state.items.isEmpty) {
      return AppErrorView(
        message: state.failure?.message ?? AppStrings.errorGeneric,
        onRetry: () =>
            context.read<CentersBloc>().add(const CentersLoadRequested()),
      );
    }

    final visible = state.filteredItems;
    if (visible.isEmpty) {
      final isSearching = state.searchQuery.trim().isNotEmpty;
      if (state.items.isNotEmpty && isSearching) {
        return const AppEmptyView(
          message: 'لا توجد مراكز مطابقة لبحثك',
          icon: Icons.search_off_rounded,
        );
      }
      return AppEmptyView(
        message: 'لا توجد مراكز مسجلة بعد',
        icon: Icons.account_balance_outlined,
        actionLabel: 'إضافة مركز',
        onAction: () => _openForm(context),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          context.read<CentersBloc>().add(const CentersLoadRequested()),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppDimensions.spacing24),
        itemCount: visible.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppDimensions.itemSpacing),
        itemBuilder: (itemContext, index) {
          final center = visible[index];
          return _CenterCard(
            center: center,
            onEdit: () => _openForm(itemContext, center: center),
            onDetails: () => _openDetails(itemContext, center: center),
          );
        },
      ),
    );
  }
}

/// بطاقة مركز واحدة: أيقونة + الاسم + الوصف + قائمة منبثقة للإجراءات.
class _CenterCard extends StatelessWidget {
  const _CenterCard({
    required this.center,
    required this.onEdit,
    required this.onDetails,
  });

  final CenterEntity center;
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
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: AppColors.primary,
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
                  center.name,
                  style: AppTypography.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (center.description.trim().isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacing4),
                  Text(
                    center.description,
                    style: AppTypography.bodySmall,
                    maxLines: 2,
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
