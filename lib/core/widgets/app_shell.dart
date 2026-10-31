import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_typography.dart';

/// عنصر تنقل في الشريط الجانبي/القائمة الجانبية.
class AppNavItem {
  const AppNavItem({
    required this.path,
    required this.label,
    required this.icon,
    this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

/// عناصر تسجّلها صفحة داخل الهيكل: أزرار AppBar وزر عائم (FAB) اختياري
/// (مثل «إضافة»). الصفحة تستدعي [set] وتنظّف بـ [clear] عند إزالتها؛
/// والمالك يمنع تعارض صفحتين عند التنقل بينهما.
class AppBarActions extends ChangeNotifier {
  AppBarActions._();

  static final AppBarActions instance = AppBarActions._();

  List<Widget> _actions = const [];
  Widget? _fab;
  Object? _owner;

  List<Widget> get actions => _actions;
  Widget? get fab => _fab;

  void set(Object owner, {List<Widget> actions = const [], Widget? fab}) {
    _owner = owner;
    _actions = actions;
    _fab = fab;
    notifyListeners();
  }

  void clear(Object owner) {
    if (_owner != owner) return;
    _owner = null;
    _actions = const [];
    _fab = null;
    notifyListeners();
  }
}

/// الهيكل العام الموحد للتطبيق: شريط جانبي على الشاشات الكبيرة
/// وقائمة جانبية (Drawer) على الشاشات الصغيرة، مع شريط حالة الاتصال.
class AppShell extends StatefulWidget {
  const AppShell({
    required this.child,
    required this.navItems,
    required this.appBarTitle,
    required this.isOnline,
    this.currentProfileName,
    this.currentProfileRole,
    this.onSignOut,
    super.key,
  });

  final Widget child;
  final List<AppNavItem> navItems;
  final String appBarTitle;

  /// حالة الاتصال الحالية لعرض شريط التحذير.
  final bool isOnline;

  final String? currentProfileName;
  final String? currentProfileRole;
  final Future<void> Function()? onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useSidebar =
        width >= AppDimensions.mobileBreakpoint + 100; // سطح المكتب/التابلت

    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _currentIndex(location);

    final content = Column(
      children: [
        // شريط تحذير انقطاع الاتصال.
        if (!widget.isOnline) _OfflineBanner(),
        Expanded(
          child: Row(
            children: [
              if (useSidebar)
                _Sidebar(
                  navItems: widget.navItems,
                  selectedIndex: selectedIndex,
                  profileName: widget.currentProfileName,
                  profileRole: widget.currentProfileRole,
                  onSignOut: widget.onSignOut,
                ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: AppDimensions.maxContentWidth,
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // إجراءات الصفحة الحالية في AppBar (تتحدث دون إعادة بناء المحتوى).
    if (useSidebar) {
      return ListenableBuilder(
        listenable: AppBarActions.instance,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text(widget.appBarTitle),
            actions: _barActions(),
          ),
          floatingActionButton: AppBarActions.instance.fab,
          body: content,
        ),
      );
    }

    // موبايل: Drawer
    return ListenableBuilder(
      listenable: AppBarActions.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.appBarTitle),
          actions: _barActions(),
          leading: Builder(
            builder: (drawerContext) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(drawerContext).openDrawer(),
            ),
          ),
        ),
        drawer: _Sidebar(
          navItems: widget.navItems,
          selectedIndex: selectedIndex,
          profileName: widget.currentProfileName,
          profileRole: widget.currentProfileRole,
          onSignOut: widget.onSignOut,
          isDrawer: true,
        ),
        floatingActionButton: AppBarActions.instance.fab,
        body: content,
      ),
    );
  }

  List<Widget> _barActions() => [
        ...AppBarActions.instance.actions,
        const SizedBox(width: AppDimensions.spacing8),
      ];

  int _currentIndex(String location) {
    int best = 0;
    int bestLength = -1;
    for (var i = 0; i < widget.navItems.length; i++) {
      final path = widget.navItems[i].path;
      if (location == path || location.startsWith('$path/')) {
        if (path.length > bestLength) {
          best = i;
          bestLength = path.length;
        }
      }
    }
    return best;
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.navItems,
    required this.selectedIndex,
    this.profileName,
    this.profileRole,
    this.onSignOut,
    this.isDrawer = false,
  });

  final List<AppNavItem> navItems;
  final int selectedIndex;
  final String? profileName;
  final String? profileRole;
  final Future<void> Function()? onSignOut;
  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: AppDimensions.sidebarWidth,
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.cardPadding),
              child: Row(
                children: [
                  Container(
                    width: AppDimensions.iconLarge + 8,
                    height: AppDimensions.iconLarge + 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.textOnPrimary,
                      size: AppDimensions.iconMedium,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'مراكز التحفيظ',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primaryDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'النظام المالي والإداري',
                          style: AppTypography.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spacing8,
                ),
                itemCount: navItems.length,
                itemBuilder: (itemContext, index) {
                  final item = navItems[index];
                  final selected = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing8,
                      vertical: AppDimensions.spacing2,
                    ),
                    child: Material(
                      color: selected
                          ? AppColors.primaryLight
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMedium),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusMedium),
                        onTap: () {
                          context.go(item.path);
                          if (isDrawer) Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacing12,
                            vertical: AppDimensions.spacing12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? (item.selectedIcon ?? item.icon)
                                    : item.icon,
                                size: AppDimensions.iconMedium,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppDimensions.spacing12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.cardPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          profileName ?? '—',
                          style: AppTypography.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profileRole == 'admin' ? 'مدير النظام' : 'مستخدم',
                          style: AppTypography.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  if (onSignOut != null)
                    IconButton(
                      tooltip: 'تسجيل الخروج',
                      onPressed: onSignOut,
                      icon: const Icon(
                        Icons.logout_rounded,
                        size: AppDimensions.iconMedium,
                        color: AppColors.error,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.cardPadding,
            vertical: AppDimensions.spacing8,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: AppColors.textOnPrimary,
                size: AppDimensions.iconMedium,
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Text(
                  'لا يوجد اتصال بالإنترنت — قد تكون البيانات المعروضة قديمة، '
                  'ولا يمكن تنفيذ العمليات المالية حتى عودة الاتصال',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textOnPrimary,
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

/// مراقب Bloc لتسجيل الأحداث والأخطاء في سجلات المطوّر.
class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    debugPrint('Bloc error (${bloc.runtimeType}): $error');
    super.onError(bloc, error, stackTrace);
  }
}
