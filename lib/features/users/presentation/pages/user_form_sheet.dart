import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/user_operation_params.dart';
import '../bloc/users_bloc.dart';

/// ورقة سفلية لإنشاء مستخدم جديد (للمديرين فقط).
///
/// كلمة المرور تمر إلى الخادم عبر الدالة السحابية فقط
/// ولا تُخزن في أي مكان إطلاقًا.
Future<void> showUserFormSheet(BuildContext context) {
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
      child: const UserFormSheet(),
    ),
  );
}

class UserFormSheet extends StatefulWidget {
  const UserFormSheet({super.key});

  @override
  State<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<UserFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _role = AppRoles.user;
  FinancialPermissions _permissions = const FinancialPermissions.none();
  bool _isActive = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<UsersBloc>().add(UsersCreateUserRequested(
          CreateUserParams(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: _role,
            financialPermissions: _permissions.toRawMap(),
            isActive: _isActive,
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    // إغلاق الورقة تلقائيًا عند اكتمال عملية الإنشاء بنجاح.
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'إضافة مستخدم جديد',
                  style: AppTypography.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacing8),
                const Text(
                  'سيتم إنشاء حساب مصادقة ومستند مستخدم عبر الخادم',
                  style: AppTypography.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacing20),
                AppTextField(
                  label: AppStrings.name,
                  controller: _nameController,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  maxLength: 200,
                  validator: AppValidators.name,
                ),
                const SizedBox(height: AppDimensions.spacing16),
                AppTextField(
                  label: AppStrings.email,
                  controller: _emailController,
                  prefixIcon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: AppValidators.email,
                ),
                const SizedBox(height: AppDimensions.spacing16),
                AppTextField(
                  label: AppStrings.password,
                  controller: _passwordController,
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  helperText: '8 أحرف على الأقل',
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: AppDimensions.iconMedium,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  validator: AppValidators.password,
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
                    if (value != null) setState(() => _role = value);
                  },
                ),
                const SizedBox(height: AppDimensions.spacing16),
                const Text('الصلاحيات المالية',
                    style: AppTypography.titleMedium),
                const Text(
                  'تحدد ما يستطيع المستخدم فعله في الشاشات المالية',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppDimensions.spacing4),
                _buildPermissionSwitch(
                  title: AppStrings.permissionView,
                  value: _role == AppRoles.admin ? true : _permissions.view,
                  onChanged: _role == AppRoles.admin
                      ? null
                      : (value) => setState(() =>
                          _permissions = _copyWithPermissions(view: value)),
                ),
                _buildPermissionSwitch(
                  title: AppStrings.permissionCreate,
                  value: _role == AppRoles.admin ? true : _permissions.create,
                  onChanged: _role == AppRoles.admin
                      ? null
                      : (value) => setState(() =>
                          _permissions = _copyWithPermissions(create: value)),
                ),
                _buildPermissionSwitch(
                  title: AppStrings.permissionUpdate,
                  value: _role == AppRoles.admin ? true : _permissions.update,
                  onChanged: _role == AppRoles.admin
                      ? null
                      : (value) => setState(() =>
                          _permissions = _copyWithPermissions(update: value)),
                ),
                _buildPermissionSwitch(
                  title: AppStrings.permissionCancel,
                  value: _role == AppRoles.admin ? true : _permissions.cancel,
                  onChanged: _role == AppRoles.admin
                      ? null
                      : (value) => setState(() =>
                          _permissions = _copyWithPermissions(cancel: value)),
                ),
                _buildPermissionSwitch(
                  title: AppStrings.permissionApprove,
                  value: _role == AppRoles.admin ? true : _permissions.approve,
                  onChanged: _role == AppRoles.admin
                      ? null
                      : (value) => setState(() =>
                          _permissions = _copyWithPermissions(approve: value)),
                ),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('تفعيل الحساب'),
                  subtitle: const Text(
                    'يمكن للمستخدم تسجيل الدخول فور إنشائه',
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: AppDimensions.spacing20),
                BlocBuilder<UsersBloc, UsersState>(
                  builder: (context, state) {
                    return AppButton(
                      label: 'إنشاء المستخدم',
                      icon: Icons.person_add_alt_rounded,
                      isLoading: state.status == UsersStatus.submitting,
                      onPressed: state.status == UsersStatus.submitting
                          ? null
                          : _submit,
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.spacing8),
                TextButton(
                  onPressed: context.read<UsersBloc>().state.status ==
                          UsersStatus.submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(AppStrings.cancel),
                ),
              ],
            ),
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
    bool? view,
    bool? create,
    bool? update,
    bool? cancel,
    bool? approve,
  }) {
    return FinancialPermissions(
      view: view ?? _permissions.view,
      create: create ?? _permissions.create,
      update: update ?? _permissions.update,
      cancel: cancel ?? _permissions.cancel,
      approve: approve ?? _permissions.approve,
    );
  }
}
