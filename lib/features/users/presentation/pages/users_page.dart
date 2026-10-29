import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_centers_finance/features/users/domain/entities/user_operation_params.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/users_bloc.dart';
import 'user_form_sheet.dart';
import 'user_permissions_sheet.dart';

/// صفحة إدارة المستخدمين — للمديرين فقط.
///
/// حماية إضافية في الواجهة: إذا لم يكن المستخدم الحالي مديرًا تُعرض
/// رسالة صلاحية (الحماية الأساسية في الراوتر والخادم).
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _searchController = TextEditingController();

  UserProfileEntity? get _currentProfile {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState.profile : null;
  }

  bool get _isAdmin => PermissionService.isAdmin(_currentProfile);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const AppErrorView(
        message: 'لا تمتلك الصلاحية لعرض هذه الشاشة',
      );
    }

    return BlocProvider(
      create: (_) => sl<UsersBloc>()..add(const UsersLoadRequested()),
      child: BlocConsumer<UsersBloc, UsersState>(
        listener: (context, state) {
          final message = state.message;
          if (message != null) {
            final isError = state.status == UsersStatus.operationFailure;
            showAppSnackBar(context, message: message, isError: isError);
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // شريط الأدوات
                Row(
                  children: [
                    const Spacer(),
                    AppButton(
                      label: 'إضافة مستخدم',
                      icon: Icons.person_add_alt_1_rounded,
                      isFullWidth: false,
                      onPressed: state.status == UsersStatus.submitting
                          ? null
                          : () => showUserFormSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.itemSpacing),

                // البحث وفلتر الدور
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: AppStrings.search,
                        controller: _searchController,
                        hintText: 'ابحث بالاسم أو البريد الإلكتروني',
                        prefixIcon: Icons.search_rounded,
                        onChanged: (value) => context
                            .read<UsersBloc>()
                            .add(UsersSearchQueryChanged(value)),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacing12),
                    Expanded(
                      child: AppDropdownField<UsersRoleFilter>(
                        label: 'الدور',
                        value: state.roleFilter,
                        items: const [
                          DropdownMenuItem(
                            value: UsersRoleFilter.all,
                            child: Text(AppStrings.all),
                          ),
                          DropdownMenuItem(
                            value: UsersRoleFilter.admins,
                            child: Text(AppStrings.roleAdmin),
                          ),
                          DropdownMenuItem(
                            value: UsersRoleFilter.users,
                            child: Text(AppStrings.roleUser),
                          ),
                        ],
                        onChanged: (filter) {
                          if (filter != null) {
                            context
                                .read<UsersBloc>()
                                .add(UsersRoleFilterChanged(filter));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.itemSpacing),

                // القائمة
                Expanded(child: _UsersList(state: state)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// قائمة المستخدمين مع حالات التحميل والفراغ والخطأ.
class _UsersList extends StatelessWidget {
  const _UsersList({required this.state});

  final UsersState state;

  @override
  Widget build(BuildContext context) {
    if ((state.status == UsersStatus.initial ||
            state.status == UsersStatus.loading) &&
        state.users.isEmpty) {
      return const AppLoadingView(message: AppStrings.loading);
    }

    if (state.status == UsersStatus.failure && state.users.isEmpty) {
      return AppErrorView(
        message: state.failure?.message ?? AppStrings.errorGeneric,
        onRetry: () =>
            context.read<UsersBloc>().add(const UsersLoadRequested()),
      );
    }

    final visible = state.visibleUsers;
    if (state.users.isEmpty) {
      return AppEmptyView(
        message: 'لا يوجد مستخدمون بعد',
        icon: Icons.group_outlined,
        actionLabel: 'إضافة مستخدم',
        onAction: () => showUserFormSheet(context),
      );
    }

    if (visible.isEmpty) {
      return const AppEmptyView(
        message: 'لا يوجد مستخدمون مطابقون للبحث أو التصفية',
        icon: Icons.person_search_outlined,
      );
    }

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.itemSpacing),
      itemBuilder: (itemContext, index) {
        final user = visible[index];
        final authState = context.read<AuthBloc>().state;
        final currentId =
            authState is AuthAuthenticated ? authState.profile.id : null;
        return _UserCard(
          user: user,
          isSelf: user.id == currentId,
        );
      },
    );
  }
}

/// بطاقة مستخدم: البيانات الأساسية + الصلاحيات المفعلة + الإجراءات.
class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.isSelf});

  final UserProfileEntity user;
  final bool isSelf;

  String get _roleLabel =>
      user.role == AppRoles.admin ? AppStrings.roleAdmin : AppStrings.roleUser;

  Future<void> _toggleActive(BuildContext context) async {
    final bloc = context.read<UsersBloc>();
    final willDisable = user.isActive;

    final confirmed = await showAppConfirmDialog(
      context,
      title: willDisable ? 'تعطيل المستخدم' : 'تفعيل المستخدم',
      message: willDisable
          ? 'سيتم منع "${user.name}" من تسجيل الدخول إلى النظام. '
              'هل تريد المتابعة؟'
          : 'سيتمكن "${user.name}" من تسجيل الدخول إلى النظام مرة أخرى. '
              'هل تريد المتابعة؟',
      confirmLabel: willDisable ? 'تعطيل' : 'تفعيل',
      isDanger: willDisable,
    );
    if (!confirmed) return;

    bloc.add(UsersUpdateUserRequested(
      UpdateUserParams(userId: user.id, isActive: !user.isActive),
    ));
  }

  Future<void> _editName(BuildContext context) async {
    final bloc = context.read<UsersBloc>();

    final newName = await showDialog<String>(
      context: context,
      barrierColor: AppColors.overlayBarrier,
      builder: (dialogContext) => _NameEditDialog(currentName: user.name),
    );

    if (newName == null || newName == user.name) return;

    bloc.add(UsersUpdateUserRequested(
      UpdateUserParams(userId: user.id, name: newName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصف الأول: الهوية + الشارات
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserAvatar(name: user.name),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: AppTypography.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacing2),
                    Text(
                      user.email,
                      style: AppTypography.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              AppStatusChip(
                label: _roleLabel,
                color: user.isAdmin ? AppColors.secondary : AppColors.info,
                backgroundColor: user.isAdmin
                    ? AppColors.secondaryLight
                    : AppColors.infoLight,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              AppStatusChip(
                label: user.isActive ? AppStrings.statusActive : 'معطل',
                color: user.isActive ? AppColors.success : AppColors.error,
                backgroundColor: user.isActive
                    ? AppColors.successLight
                    : AppColors.errorLight,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),

          // شريط الصلاحيات المالية المفعلة
          _PermissionsStrip(user: user),
          const SizedBox(height: AppDimensions.spacing12),

          // الإجراءات — تعديل الدور/الصلاحيات والتعطيل مخفيان لحساب
          // المستخدم الحالي (الخادم يمنعها أيضًا).
          Row(
            children: [
              if (!isSelf)
                TextButton.icon(
                  onPressed: () => showUserPermissionsSheet(context, user),
                  icon: const Icon(Icons.admin_panel_settings_outlined,
                      size: AppDimensions.iconSmall + 2),
                  label: const Text('تعديل الصلاحيات'),
                ),
              const SizedBox(width: AppDimensions.spacing8),
              TextButton.icon(
                onPressed: () => _editName(context),
                icon: const Icon(Icons.edit_outlined,
                    size: AppDimensions.iconSmall + 2),
                label: const Text('تعديل الاسم'),
              ),
              const Spacer(),
              // تعطيل الذات غير مسموح (الخادم يمنعها أيضًا).
              if (!isSelf)
                TextButton.icon(
                  onPressed: () => _toggleActive(context),
                  icon: Icon(
                    user.isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_outline_rounded,
                    size: AppDimensions.iconSmall + 2,
                  ),
                  label: Text(user.isActive ? 'تعطيل' : 'تفعيل'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        user.isActive ? AppColors.error : AppColors.success,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// حوار تعديل اسم المستخدم — يملك متحكم الحقل ويتخلص منه بنفسه.
class _NameEditDialog extends StatefulWidget {
  const _NameEditDialog({required this.currentName});

  final String currentName;

  @override
  State<_NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<_NameEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل الاسم'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AppTextField(
          label: AppStrings.name,
          controller: _nameController,
          maxLength: 200,
          validator: AppValidators.name,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        AppButton(
          label: AppStrings.save,
          isFullWidth: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// أول حرف من الاسم داخل دائرة ملونة.
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0] : '؟';
    return Container(
      width: AppDimensions.avatarRadius * 2,
      height: AppDimensions.avatarRadius * 2,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppTypography.titleLarge.copyWith(
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// شريط صغير يعرض الصلاحيات المالية المفعلة كأيقونات مع تسميات.
class _PermissionsStrip extends StatelessWidget {
  const _PermissionsStrip({required this.user});

  final UserProfileEntity user;

  static const Map<String, (IconData, String)> _definitions = {
    AppPermissions.view: (Icons.visibility_outlined, AppStrings.permissionView),
    AppPermissions.create: (
      Icons.add_circle_outline_rounded,
      AppStrings.permissionCreate
    ),
    AppPermissions.update: (Icons.edit_outlined, AppStrings.permissionUpdate),
    AppPermissions.cancel: (Icons.cancel_outlined, AppStrings.permissionCancel),
    AppPermissions.approve: (
      Icons.task_alt_rounded,
      AppStrings.permissionApprove
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (user.isAdmin) {
      return const Text(
        'يمتلك كل الصلاحيات المالية ضمنيًا بصفته مديرًا',
        style: AppTypography.bodySmall,
      );
    }

    final enabled = AppPermissions.all
        .where((key) => user.financialPermissions.toRawMap()[key] == true)
        .toList();

    if (enabled.isEmpty) {
      return Text(
        'لا صلاحيات مالية مفعلة',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    return Wrap(
      spacing: AppDimensions.spacing8,
      runSpacing: AppDimensions.spacing8,
      children: [
        for (final key in enabled)
          Tooltip(
            message: _definitions[key]!.$2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing8,
                vertical: AppDimensions.spacing4,
              ),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _definitions[key]!.$1,
                    size: AppDimensions.iconSmall,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppDimensions.spacing4),
                  Text(
                    _definitions[key]!.$2,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
