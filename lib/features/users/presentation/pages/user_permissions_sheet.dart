import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/user_operation_params.dart';
import '../bloc/users_bloc.dart';

/// ورقة سفلية لتعديل صلاحيات ودور مستخدم قائم (للمديرين فقط).
///
/// تعتمد على UsersUpdateUserRequested في UsersBloc — التحقق النهائي
/// يتم على الخادم (لا يمكن لأي مدير تعديل بياناته الحساسة بنفسه).
Future<void> showUserPermissionsSheet(
  BuildContext context,
  UserProfileEntity user,
) {
  final usersBloc = context.read<UsersBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusExtraLarge),
      ),
    ),
    builder: (_) => BlocProvider<UsersBloc>.value(
      value: usersBloc,
      child: UserPermissionsSheet(user: user),
    ),
  );
}

class UserPermissionsSheet extends StatefulWidget {
  const UserPermissionsSheet({required this.user, super.key});

  final UserProfileEntity user;

  @override
  State<UserPermissionsSheet> createState() => _UserPermissionsSheetState();
}

class _UserPermissionsSheetState extends State<UserPermissionsSheet> {
  late String _role = widget.user.role;
  late FinancialPermissions _permissions = widget.user.financialPermissions;

  bool get _isAdminRole => _role == AppRoles.admin;

  bool get _isSubmitting =>
      context.read<UsersBloc>().state.status == UsersStatus.submitting;

  void _submit() {
    context.read<UsersBloc>().add(UsersUpdateUserRequested(
          UpdateUserParams(
            userId: widget.user.id,
            role: _role,
            // للمدير تُرسل كل الصلاحيات مفعلة (يمتلكها ضمنيًا على الخادم).
            financialPermissions: _isAdminRole
                ? const FinancialPermissions.all().toRawMap()
                : _permissions.toRawMap(),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UsersBloc, UsersState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == UsersStatus.operationCompleted,
      listener: (context, state) {
        Navigator.of(context).pop();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.cardPaddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تعديل صلاحيات: ${widget.user.name}',
                style: AppTypography.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                widget.user.email,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacing16),

              // تحذير: التحقق النهائي على الخادم.
              Container(
                padding: const EdgeInsets.all(AppDimensions.spacing12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                ),
                child: Text(
                  'التحقق النهائي يتم على الخادم — '
                  'لا يمكن تعديل بياناتك الحساسة بنفسك',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacing16),

              AppDropdownField<String>(
                label: 'الدور',
                value: _role,
                items: AppRoles.all
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(
                          role == AppRoles.admin
                              ? AppStrings.roleAdmin
                              : AppStrings.roleUser,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null || value == _role) return;
                  setState(() {
                    _role = value;
                    // عند الترقية إلى مدير تُعرض كل الصلاحيات مفعلة.
                    if (_isAdminRole) {
                      _permissions = const FinancialPermissions.all();
                    }
                  });
                },
              ),
              const SizedBox(height: AppDimensions.spacing16),

              const Text('الصلاحيات المالية', style: AppTypography.titleMedium),
              if (_isAdminRole)
                const Text(
                  'المدير يمتلك كل الصلاحيات ضمنيًا',
                  style: AppTypography.bodySmall,
                ),
              const SizedBox(height: AppDimensions.spacing4),
              _buildPermissionSwitch(
                title: AppStrings.permissionCreate,
                value: _isAdminRole ? true : _permissions.create,
                onChanged: _isAdminRole
                    ? null
                    : (value) => setState(() =>
                        _permissions = _copyWithPermissions(create: value)),
              ),
              _buildPermissionSwitch(
                title: AppStrings.permissionUpdate,
                value: _isAdminRole ? true : _permissions.update,
                onChanged: _isAdminRole
                    ? null
                    : (value) => setState(() =>
                        _permissions = _copyWithPermissions(update: value)),
              ),
              _buildPermissionSwitch(
                title: AppStrings.permissionCancel,
                value: _isAdminRole ? true : _permissions.cancel,
                onChanged: _isAdminRole
                    ? null
                    : (value) => setState(() =>
                        _permissions = _copyWithPermissions(cancel: value)),
              ),
              _buildPermissionSwitch(
                title: AppStrings.permissionApprove,
                value: _isAdminRole ? true : _permissions.approve,
                onChanged: _isAdminRole
                    ? null
                    : (value) => setState(() =>
                        _permissions = _copyWithPermissions(approve: value)),
              ),
              const SizedBox(height: AppDimensions.spacing20),

              BlocBuilder<UsersBloc, UsersState>(
                builder: (context, state) {
                  return AppButton(
                    label: AppStrings.save,
                    icon: Icons.save_outlined,
                    isLoading: state.status == UsersStatus.submitting,
                    onPressed:
                        state.status == UsersStatus.submitting ? null : _submit,
                  );
                },
              ),
              const SizedBox(height: AppDimensions.spacing8),
              TextButton(
                onPressed:
                    _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text(AppStrings.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  FinancialPermissions _copyWithPermissions({
    bool? create,
    bool? update,
    bool? cancel,
    bool? approve,
  }) {
    return FinancialPermissions(
      create: create ?? _permissions.create,
      update: update ?? _permissions.update,
      cancel: cancel ?? _permissions.cancel,
      approve: approve ?? _permissions.approve,
    );
  }
}
