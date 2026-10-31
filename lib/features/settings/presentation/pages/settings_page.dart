import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/user_entity.dart';
import '../../../../core/services/pending_operations_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/app_lock_service.dart';
import '../../../../core/services/biometric_auth_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_page_widgets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../cubit/settings_cubit.dart';

/// صفحة الإعدادات: الملف الشخصي، الاتصال، التخزين المحلي،
/// تفضيلات العرض، الجلسة، وحول التطبيق.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final initialProfile =
        authState is AuthAuthenticated ? authState.profile : null;

    return BlocProvider<SettingsCubit>(
      create: (_) => sl<SettingsCubit>()..updateProfile(initialProfile),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    // مزامنة الملف الشخصي مع تغيرات AuthBloc (دور/صلاحيات/حالة نشط).
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        final profile =
            authState is AuthAuthenticated ? authState.profile : null;
        context.read<SettingsCubit>().updateProfile(profile);
      },
      child: BlocConsumer<SettingsCubit, SettingsState>(
        listener: (context, state) {
          final message = state.message;
          if (message == null) return;
          final isError = state.status == SettingsStatus.cacheFailure ||
              state.status == SettingsStatus.preferenceFailure;
          showAppSnackBar(context, message: message, isError: isError);
        },
        builder: (context, state) {
          return AppPageScroll(
            maxWidth: 720,
            children: [
              const AppPageHeader(
                title: AppStrings.navSettings,
                subtitle: 'إدارة حسابك وتفضيلات التطبيق',
              ),
              const SizedBox(height: AppDimensions.sectionSpacing),
              _ProfileSection(
                profile: state.profile,
                isOnline: state.isOnline,
              ),
              const SizedBox(height: AppDimensions.sectionSpacing),
              const _GroupLabel('الأمان والعرض'),
              _AppLockSection(profile: state.profile),
              const SizedBox(height: AppDimensions.itemSpacing),
              _DisplaySection(isDarkMode: state.isDarkMode),
              const SizedBox(height: AppDimensions.sectionSpacing),
              const _GroupLabel('البيانات والجلسة'),
              const _StorageSection(),
              const SizedBox(height: AppDimensions.itemSpacing),
              const _SessionSection(),
              const SizedBox(height: AppDimensions.sectionSpacing),
              const _AboutSection(),
              const SizedBox(height: AppDimensions.sectionSpacing),
            ],
          );
        },
      ),
    );
  }
}

/// قسم الملف الشخصي: بطاقة بارزة (الاسم/البريد/الدور/حالة الاتصال)
/// + بطاقة الصلاحيات المالية.
class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.profile, required this.isOnline});

  final UserProfileEntity? profile;
  final bool isOnline;

  static const List<(PermissionAction, String)> _permissionLabels = [
    (PermissionAction.view, AppStrings.permissionView),
    (PermissionAction.create, AppStrings.permissionCreate),
    (PermissionAction.update, AppStrings.permissionUpdate),
    (PermissionAction.cancel, AppStrings.permissionCancel),
    (PermissionAction.approve, AppStrings.permissionApprove),
  ];

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final user = profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppHeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: AppDimensions.avatarRadiusLarge,
                    backgroundColor: AppColors.onHeroSurface,
                    child: Text(
                      user == null ? '…' : _initial(user.name),
                      style: AppTypography.headlineLarge.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing16),
                  Expanded(
                    child: user == null
                        ? Text(
                            AppStrings.loading,
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.onHeroMuted,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: AppTypography.headlineSmall.copyWith(
                                  color: AppColors.textOnPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppDimensions.spacing2),
                              Text(
                                user.email,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.onHeroMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing16),
              Wrap(
                spacing: AppDimensions.spacing8,
                runSpacing: AppDimensions.spacing8,
                children: [
                  if (user != null)
                    AppHeroPill(
                      label: user.isAdmin
                          ? AppStrings.roleAdmin
                          : AppStrings.roleUser,
                    ),
                  _ConnectivityPill(isOnline: isOnline),
                ],
              ),
            ],
          ),
        ),
        if (user != null) ...[
          const SizedBox(height: AppDimensions.itemSpacing),
          AppCard(
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  icon: Icons.verified_user_rounded,
                  title: 'الصلاحيات المالية',
                ),
                if (user.isAdmin) ...[
                  const SizedBox(height: AppDimensions.spacing8),
                  const Text(
                    'المدير يمتلك كل الصلاحيات ضمنيًا',
                    style: AppTypography.bodySmall,
                  ),
                ],
                const SizedBox(height: AppDimensions.spacing12),
                ..._permissionLabels.map(
                  (entry) => _PermissionRow(
                    label: entry.$2,
                    granted: PermissionService.can(user, entry.$1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// صف صلاحية واحدة: أيقونة تحقق أو بلا + التسمية العربية.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing4),
      child: Row(
        children: [
          Icon(
            granted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: AppDimensions.iconSmall + 2,
            color: granted ? AppColors.success : AppColors.disabled,
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color:
                    granted ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شريحة حالة الاتصال داخل البطاقة البارزة (نقطة + نص).
class _ConnectivityPill extends StatelessWidget {
  const _ConnectivityPill({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing4,
      ),
      decoration: BoxDecoration(
        color: AppColors.onHeroSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppDimensions.spacing8,
            height: AppDimensions.spacing8,
            decoration: BoxDecoration(
              color: isOnline ? AppColors.successLight : AppColors.warningLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Text(
            isOnline ? 'متصل بالإنترنت' : 'غير متصل — وضع محدود',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textOnPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// عنوان مجموعة إعدادات (نص صغير فوق البطاقات).
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing8),
      child: Text(
        text,
        style: AppTypography.titleSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// ترويسة قسم داخل بطاقة: شارة أيقونة + عنوان + سطر فرعي اختياري.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = AppColors.primary,
    this.background = AppColors.primaryLight,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIconBadge(icon: icon, color: color, background: background),
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.headlineSmall),
              if (subtitle != null)
                Text(subtitle!, style: AppTypography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// قسم التخزين المحلي: توضيح + زر مسح البيانات المؤقتة.
class _StorageSection extends StatelessWidget {
  const _StorageSection();

  Future<void> _confirmClear(BuildContext context) async {
    // التحقق من وجود عمليات معلقة قبل المسح
    final pendingService = sl<PendingOperationsService>();
    final pendingCount = pendingService.pendingCount;

    if (pendingCount > 0 && context.mounted) {
      // إبلاغ المستخدم بأن العمليات المعلقة لن تُمسح
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: AppDimensions.iconMedium),
              SizedBox(width: AppDimensions.spacing8),
              Expanded(child: Text('عمليات مالية معلقة')),
            ],
          ),
          content: Text(
            'لديك ($pendingCount) '
            '${pendingCount == 1 ? 'عملية معلقة' : 'عمليات معلقة'} '
            'بانتظار عودة الإنترنت.\n\n'
            'لن يتم مسحها حفاظًا على بياناتك المالية، '
            'وستتم مزامنتها تلقائيًا فور عودة الاتصال.\n\n'
            'سيُمسح فقط: ذاكرة التخزين المؤقت للقوائم (المراكز، الفروع، الظروف، المستخدمين).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('فهمت، إلغاء'),
            ),
            AppButton(
              label: 'مسح الكاش فقط',
              icon: Icons.cleaning_services_rounded,
              variant: AppButtonVariant.secondary,
              isFullWidth: false,
              onPressed: () => Navigator.of(ctx).pop('confirm'),
            ),
          ],
        ),
      );
      if (result != 'confirm') return;
      if (!context.mounted) return;
      context.read<SettingsCubit>().clearCache();
      return;
    }

    // لا توجد عمليات معلقة — حوار التأكيد المعتاد
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'مسح البيانات المؤقتة',
      message:
          'سيتم مسح ذاكرة التخزين المؤقت للقوائم (المراكز، الفروع، الظروف، المستخدمين). '
          'لا يؤثر ذلك على بيانات الخادم أو الأرصدة المالية.',
      confirmLabel: 'مسح',
      isDanger: true,
    );
    if (!confirmed) return;
    if (!context.mounted) return;
    context.read<SettingsCubit>().clearCache();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.storage_rounded,
            title: 'التخزين المحلي',
            subtitle: 'Hive للتخزين المؤقت فقط وليس مصدرًا للأرصدة '
                'أو الصلاحيات. كل البيانات الموثوقة تُقرأ من الخادم.',
          ),
          const SizedBox(height: AppDimensions.spacing16),
          BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, state) {
              return AppButton(
                label: 'مسح البيانات المؤقتة',
                icon: Icons.cleaning_services_rounded,
                variant: AppButtonVariant.secondary,
                isLoading: state.isBusy,
                onPressed: state.isBusy ? null : () => _confirmClear(context),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// قسم العرض: تفضيل الوضع الداكن (حفظ فقط — التنفيذ لاحقًا).
class _DisplaySection extends StatelessWidget {
  const _DisplaySection({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      child: SwitchListTile(
        value: isDarkMode,
        onChanged: (value) =>
            context.read<SettingsCubit>().toggleDarkMode(value),
        secondary: const AppIconBadge(
          icon: Icons.dark_mode_rounded,
          color: AppColors.info,
          background: AppColors.infoLight,
        ),
        title: const Text('الوضع الداكن'),
        subtitle: const Text(
          'يُحفظ تفضيلك الآن — سيتم تطبيق الثيم الداكن في إصدار قادم',
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

/// إعداد قفل التطبيق: يُحفظ لكل حساب على الجهاز الحالي فقط.
class _AppLockSection extends StatefulWidget {
  const _AppLockSection({required this.profile});

  final UserProfileEntity? profile;

  @override
  State<_AppLockSection> createState() => _AppLockSectionState();
}

class _AppLockSectionState extends State<_AppLockSection> {
  final AppLockService _appLock = AppLockService();
  final BiometricAuthService _biometric = BiometricAuthService();
  bool _loading = true;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AppLockSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.id != widget.profile?.id) _load();
  }

  Future<void> _load() async {
    final userId = widget.profile?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _enabled = false;
        });
      }
      return;
    }
    final enabled = await _appLock.isEnabled(userId);
    if (mounted) {
      setState(() {
        _loading = false;
        _enabled = enabled;
      });
    }
  }

  Future<void> _setEnabled(bool value) async {
    final userId = widget.profile?.id;
    if (userId == null) return;

    if (!value) {
      await _appLock.disable(userId);
      if (mounted) setState(() => _enabled = false);
      return;
    }

    final passcode = await _showCreatePasscodeDialog();
    if (passcode == null || !mounted) return;

    setState(() => _loading = true);
    final verified = await _biometric.authenticate();
    if (!verified) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnackBar(
          context,
          message: 'لم يتم التحقق بالبصمة؛ لم يُفعّل القفل',
          isError: true,
        );
      }
      return;
    }

    await _appLock.enable(userId: userId, passcode: passcode);
    if (mounted) {
      setState(() {
        _loading = false;
        _enabled = true;
      });
      showAppSnackBar(context, message: 'تم تفعيل قفل البصمة بنجاح');
    }
  }

  Future<String?> _showCreatePasscodeDialog() => showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _CreateAppPasscodeDialog(),
      );

  @override
  Widget build(BuildContext context) {
    final canConfigure = widget.profile != null && !_loading;
    return AppCard(
      elevated: true,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _enabled,
        onChanged: canConfigure ? _setEnabled : null,
        secondary: const AppIconBadge(
          icon: Icons.fingerprint_rounded,
          color: AppColors.primary,
          background: AppColors.primaryLight,
        ),
        title: const Text('قفل التطبيق بالبصمة'),
        subtitle: const Text(
          'عند الفتح أو العودة من الخلفية ستُطلب البصمة. أنشئ كلمة مرور '
          'للاسترداد عند تعذر البصمة.',
        ),
      ),
    );
  }
}

class _CreateAppPasscodeDialog extends StatefulWidget {
  const _CreateAppPasscodeDialog();

  @override
  State<_CreateAppPasscodeDialog> createState() =>
      _CreateAppPasscodeDialogState();
}

class _CreateAppPasscodeDialogState extends State<_CreateAppPasscodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passcode = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _passcode.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_passcode.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('إنشاء كلمة مرور التطبيق'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _passcode,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور (4 إلى 8 أرقام)',
                ),
                validator: (value) => RegExp(r'^\d{4,8}$').hasMatch(value ?? '')
                    ? null
                    : 'أدخل من 4 إلى 8 أرقام',
              ),
              TextFormField(
                controller: _confirmation,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration:
                    const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                validator: (value) => value == _passcode.text
                    ? null
                    : 'كلمتا المرور غير متطابقتين',
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          AppButton(
            label: 'متابعة',
            isFullWidth: false,
            onPressed: _submit,
          ),
        ],
      );
}

/// قسم الجلسة: زر تسجيل الخروج مع حوار تأكيد.
class _SessionSection extends StatelessWidget {
  const _SessionSection();

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.signOut,
      message: AppStrings.signOutConfirm,
      confirmLabel: AppStrings.signOut,
      isDanger: true,
    );
    if (!confirmed) return;
    if (!context.mounted) return;
    context.read<AuthBloc>().add(const AuthSignOutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.manage_accounts_rounded,
            title: 'الجلسة',
            subtitle: 'سيتم مسح البيانات المؤقتة المحلية عند تسجيل الخروج',
            color: AppColors.error,
            background: AppColors.errorLight,
          ),
          const SizedBox(height: AppDimensions.spacing16),
          AppButton(
            label: AppStrings.signOut,
            icon: Icons.logout_rounded,
            variant: AppButtonVariant.danger,
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }
}

/// قسم حول التطبيق: الاسم + الإصدار + ملاحظة الخادم.
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.info_rounded,
            title: 'حول التطبيق',
            color: AppColors.secondary,
            background: AppColors.secondaryLight,
          ),
          SizedBox(height: AppDimensions.spacing12),
          AppInfoRow(label: 'اسم التطبيق', value: AppStrings.appName),
          AppInfoRow(label: 'الإصدار', value: '1.0.0'),
          SizedBox(height: AppDimensions.spacing8),
          Row(
            children: [
              Icon(Icons.verified_user_outlined,
                  size: AppDimensions.iconSmall + 2, color: AppColors.success),
              SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(
                  AppStrings.serverOnlyWarning,
                  style: AppTypography.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
