import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/data/models/envelope_model.dart';
import '../../../../core/data/models/transaction_model.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/services/financial_operations_service.dart';
import '../../../../core/services/operation_submitter.dart';
import '../../../../core/services/pending_operation_handlers.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_amount_text.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_widgets.dart';
import '../../../../core/widgets/app_shell.dart' show AppBarActions;
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../branches/data/models/branch_model.dart';
import '../../../centers/data/models/center_model.dart';

/// سجل الحركات النقدية الفعلي؛ البحث والتصفية محليان لتجنب فهارس مركبة جديدة.
/// التصميم: ملخص سريع، فلاتر بشرائح، وقائمة مجمعة حسب اليوم مع تفاصيل قابلة للتوسيع.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _searchController = TextEditingController();
  String _type = _Filter.all;
  String _status = _Filter.all;
  String _category = _Filter.all;
  String _center = _Filter.all;
  String _branch = _Filter.all;
  String _envelope = _Filter.all;
  bool _newestFirst = true;

  /// التقسيم المحلي: عدد الحركات المعروضة (القراءة من Firestore كما هي).
  static const int _pageSize = 30;
  int _visibleCount = _pageSize;

  /// مستمع واحد للصفحة كلها: إنشاؤه داخل build كان يعيد الاشتراك
  /// عند كل ضغطة بحث أو تغيير فلتر.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _transactionsStream =
      FirebaseFirestore.instance
          .collection(AppCollections.transactions)
          .snapshots();

  /// أي تغيير في الفلاتر/الترتيب/البحث يعيد العرض إلى أول صفحة.
  void _applyFilter(VoidCallback change) => setState(() {
        change();
        _visibleCount = _pageSize;
      });

  /// معرّف الحركة قيد الإلغاء حاليًا (المؤشر يظهر في بطاقتها وحدها).
  String? _cancellingId;

  bool? _syncedCanCreate;

  @override
  void dispose() {
    _searchController.dispose();
    // التنظيف بعد الإطار: الإشعار أثناء تفكيك الشجرة غير مسموح.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => AppBarActions.instance.clear(this));
    super.dispose();
  }

  /// زر «إضافة حركة» العائم في الهيكل العام (لمن يملك صلاحية الإنشاء فقط).
  void _syncCreateAction(bool canCreate) {
    if (_syncedCanCreate == canCreate) return;
    _syncedCanCreate = canCreate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppBarActions.instance.set(
        this,
        fab: canCreate
            ? FloatingActionButton.extended(
                onPressed: _showCreateTransaction,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة حركة'),
              )
            : null,
      );
    });
  }

  bool get _hasActiveFilters =>
      _type != _Filter.all ||
      _status != _Filter.all ||
      _category != _Filter.all ||
      _center != _Filter.all ||
      _branch != _Filter.all ||
      _envelope != _Filter.all ||
      _searchController.text.trim().isNotEmpty;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _type = _Filter.all;
      _status = _Filter.all;
      _category = _Filter.all;
      _center = _Filter.all;
      _branch = _Filter.all;
      _envelope = _Filter.all;
      _visibleCount = _pageSize;
    });
  }

  List<TransactionModel> _filtered(List<TransactionModel> source) {
    final search = _searchController.text.trim().toLowerCase();
    final items = source.where((item) {
      final haystack = '${item.name ?? ''} ${item.notes} ${item.category} '
              '${item.paymentMethod} ${item.id}'
          .toLowerCase();
      return (_type == _Filter.all || item.type == _type) &&
          (_status == _Filter.all || item.status == _status) &&
          (_category == _Filter.all || item.category == _category) &&
          (_center == _Filter.all || item.centerId == _center) &&
          (_branch == _Filter.all || item.branchId == _branch) &&
          (_envelope == _Filter.all || item.envelopeId == _envelope) &&
          (search.isEmpty || haystack.contains(search));
    }).toList()
      ..sort(
        (a, b) => _newestFirst
            ? b.createdAt.compareTo(a.createdAt)
            : a.createdAt.compareTo(b.createdAt),
      );
    return items;
  }

  Future<void> _cancel(TransactionModel transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الحركة'),
        content: Text(
          'سيُعاد أثر «${_titleFor(transaction)}» على رصيد الظرف. '
          'لا يمكن التراجع عن الإلغاء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('إلغاء الحركة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_cancellingId != null) return;
    setState(() => _cancellingId = transaction.id);
    try {
      await sl<FinancialOperationsService>().call(
        AppFunctions.cancelTransaction,
        {'transactionId': transaction.id},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الحركة وتحديث الرصيد.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إلغاء الحركة: ${ErrorText.of(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancellingId = null);
    }
  }

  Future<void> _showCreateTransaction() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _CreateTransactionDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final profile =
            authState is AuthAuthenticated ? authState.profile : null;
        _syncCreateAction(
          PermissionService.canCreateEntries(profile),
        );
        if (!PermissionService.isActive(profile)) {
          return const AppErrorView(
            message: 'ليس لديك صلاحية عرض الحركات المالية.',
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _transactionsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorView(
                message: 'تعذر تحميل الحركات المالية: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all =
                snapshot.data!.docs.map(TransactionModel.fromSnapshot).toList();
            return _TransactionsView(
              all: all,
              visible: _filtered(all),
              searchController: _searchController,
              type: _type,
              status: _status,
              category: _category,
              center: _center,
              branch: _branch,
              envelope: _envelope,
              newestFirst: _newestFirst,
              hasActiveFilters: _hasActiveFilters,
              cancellingId: _cancellingId,
              canCancel: PermissionService.isAdmin(profile),
              visibleCount: _visibleCount,
              onLoadMore: () => setState(() => _visibleCount += _pageSize),
              onSearchChanged: () => _applyFilter(() {}),
              onTypeChanged: (value) => _applyFilter(() => _type = value),
              onStatusChanged: (value) => _applyFilter(() => _status = value),
              onCategoryChanged: (value) =>
                  _applyFilter(() => _category = value),
              onCenterChanged: (value) => _applyFilter(() {
                _center = value;
                _branch = _Filter.all;
              }),
              onBranchChanged: (value) => _applyFilter(() => _branch = value),
              onEnvelopeChanged: (value) =>
                  _applyFilter(() => _envelope = value),
              onToggleSort: () =>
                  _applyFilter(() => _newestFirst = !_newestFirst),
              onClearFilters: _clearFilters,
              onCancel: _cancel,
            );
          },
        );
      },
    );
  }
}

class _TransactionsView extends StatelessWidget {
  const _TransactionsView({
    required this.all,
    required this.visible,
    required this.searchController,
    required this.type,
    required this.status,
    required this.category,
    required this.center,
    required this.branch,
    required this.envelope,
    required this.newestFirst,
    required this.hasActiveFilters,
    required this.cancellingId,
    required this.canCancel,
    required this.visibleCount,
    required this.onLoadMore,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onCenterChanged,
    required this.onBranchChanged,
    required this.onEnvelopeChanged,
    required this.onToggleSort,
    required this.onClearFilters,
    required this.onCancel,
  });

  final List<TransactionModel> all;
  final List<TransactionModel> visible;
  final TextEditingController searchController;
  final String type;
  final String status;
  final String category;
  final String center;
  final String branch;
  final String envelope;
  final bool newestFirst;
  final bool hasActiveFilters;
  final String? cancellingId;
  final bool canCancel;
  final int visibleCount;
  final VoidCallback onLoadMore;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onCenterChanged;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<String> onEnvelopeChanged;
  final VoidCallback onToggleSort;
  final VoidCallback onClearFilters;
  final ValueChanged<TransactionModel> onCancel;

  num _sum(Iterable<TransactionModel> items, String type) => items
      .where((item) =>
          item.status == AppStatuses.active && item.type == type)
      .fold<num>(0, (value, item) => value + item.amount);

  @override
  Widget build(BuildContext context) {
    final income = _sum(all, AppTransactionTypes.income);
    final expense = _sum(all, AppTransactionTypes.expense);
    final visibleIncome = _sum(visible, AppTransactionTypes.income);
    final visibleExpense = _sum(visible, AppTransactionTypes.expense);

    final categories = all
        .map((item) => item.category)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => _categoryLabel(a).compareTo(_categoryLabel(b)));

    final shown = visible.length > visibleCount
        ? visible.sublist(0, visibleCount)
        : visible;
    final remaining = visible.length - shown.length;
    final groups = _groupByDay(shown);

    return AppPageScroll(
      children: [
        _SummaryTiles(income: income, expense: expense, count: all.length),
        const SizedBox(height: AppDimensions.sectionSpacing),
        _FiltersCard(
          searchController: searchController,
          type: type,
          status: status,
          category: category,
          categories: categories,
          center: center,
          branch: branch,
          envelope: envelope,
          hasActiveFilters: hasActiveFilters,
          onSearchChanged: onSearchChanged,
          onTypeChanged: onTypeChanged,
          onStatusChanged: onStatusChanged,
          onCategoryChanged: onCategoryChanged,
          onCenterChanged: onCenterChanged,
          onBranchChanged: onBranchChanged,
          onEnvelopeChanged: onEnvelopeChanged,
          onClearFilters: onClearFilters,
        ),
        const SizedBox(height: AppDimensions.sectionSpacing),
        AppSectionTitle(
          title: 'الحركات (${visible.length})',
          trailing: TextButton.icon(
            onPressed: onToggleSort,
            icon: const Icon(Icons.swap_vert_rounded),
            label: Text(newestFirst ? 'الأحدث أولًا' : 'الأقدم أولًا'),
          ),
        ),
        if (hasActiveFilters && visible.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacing8),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              _InlinePill(
                label: 'إيراد المعروض',
                value: AppFormatters.amountCompact(visibleIncome),
                color: AppColors.income,
                background: AppColors.incomeLight,
              ),
              _InlinePill(
                label: 'مصروف المعروض',
                value: AppFormatters.amountCompact(visibleExpense),
                color: AppColors.expense,
                background: AppColors.expenseLight,
              ),
            ],
          ),
        ],
        const SizedBox(height: AppDimensions.spacing12),
        if (visible.isEmpty)
          _EmptyTransactions(
            hasActiveFilters: hasActiveFilters,
            onClearFilters: onClearFilters,
          )
        else
          for (final group in groups)
            _DaySection(
              group: group,
              canCancel: canCancel,
              cancellingId: cancellingId,
              onCancel: onCancel,
            ),
        if (remaining > 0) ...[
          const SizedBox(height: AppDimensions.spacing12),
          Center(
            child: OutlinedButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more_rounded),
              label: Text(
                'عرض المزيد (${AppFormatters.integer(remaining)} متبقية)',
              ),
            ),
          ),
        ],
        // مساحة سفلية حتى لا يغطي الزر العائم آخر حركة.
        const SizedBox(height: 88),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// الملخص
// ─────────────────────────────────────────────────────────────────────────────

/// ملخص الحركات في بطاقة بارزة واحدة: الصافي كرقم رئيسي، شريط يوضح نسبة
/// الإيراد إلى المصروف، ثم الإيرادات والمصروفات وعدد الحركات.
class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({
    required this.income,
    required this.expense,
    required this.count,
  });

  final num income;
  final num expense;
  final int count;

  @override
  Widget build(BuildContext context) {
    final net = income - expense;
    final total = income + expense;
    final incomeFlex = total <= 0 ? 1 : (income / total * 1000).round();
    final expenseFlex = total <= 0 ? 1 : (expense / total * 1000).round();

    return AppHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'الرصيد الصافي للحركات',
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.onHeroMuted,
                  ),
                ),
              ),
              AppHeroPill(label: '${AppFormatters.integer(count)} حركة'),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              AppFormatters.amountSigned(net),
              style: AppTypography.displayLarge.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            child: SizedBox(
              height: AppDimensions.spacing8,
              child: total <= 0
                  ? const ColoredBox(color: AppColors.onHeroSurface)
                  : Row(
                      children: [
                        Expanded(
                          flex: incomeFlex,
                          child: const ColoredBox(color: AppColors.successLight),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: expenseFlex,
                          child: const ColoredBox(color: AppColors.warning),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          AppResponsiveGrid(
            minItemWidth: 160,
            maxColumns: 2,
            children: [
              AppHeroMetric(
                label: 'إجمالي الإيرادات',
                value: AppFormatters.amount(income),
                icon: Icons.south_west_rounded,
              ),
              AppHeroMetric(
                label: 'إجمالي المصروفات',
                value: AppFormatters.amount(expense),
                icon: Icons.north_east_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlinePill extends StatelessWidget {
  const _InlinePill({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing12,
        vertical: AppDimensions.spacing4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.labelMedium),
          const SizedBox(width: AppDimensions.spacing8),
          Text(value, style: AppTypography.titleMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// الفلاتر
// ─────────────────────────────────────────────────────────────────────────────

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.searchController,
    required this.type,
    required this.status,
    required this.category,
    required this.categories,
    required this.center,
    required this.branch,
    required this.envelope,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onCenterChanged,
    required this.onBranchChanged,
    required this.onEnvelopeChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final String type;
  final String status;
  final String category;
  final List<String> categories;
  final String center;
  final String branch;
  final String envelope;
  final bool hasActiveFilters;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onCenterChanged;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<String> onEnvelopeChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final categoryValue =
        category == _Filter.all || categories.contains(category)
            ? category
            : _Filter.all;

    return AppCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: (_) => onSearchChanged(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'ابحث بالاسم أو التصنيف أو الملاحظات',
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged();
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          const Text('النوع', style: AppTypography.labelMedium),
          const SizedBox(height: AppDimensions.spacing8),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              AppChoiceChip(
                label: 'كل الأنواع',
                selected: type == _Filter.all,
                onTap: () => onTypeChanged(_Filter.all),
              ),
              AppChoiceChip(
                label: 'إيراد',
                icon: Icons.south_west_rounded,
                selected: type == AppTransactionTypes.income,
                onTap: () => onTypeChanged(AppTransactionTypes.income),
              ),
              AppChoiceChip(
                label: 'مصروف',
                icon: Icons.north_east_rounded,
                selected: type == AppTransactionTypes.expense,
                onTap: () => onTypeChanged(AppTransactionTypes.expense),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          const Text('الحالة', style: AppTypography.labelMedium),
          const SizedBox(height: AppDimensions.spacing8),
          Wrap(
            spacing: AppDimensions.spacing8,
            runSpacing: AppDimensions.spacing8,
            children: [
              AppChoiceChip(
                label: 'كل الحالات',
                selected: status == _Filter.all,
                onTap: () => onStatusChanged(_Filter.all),
              ),
              AppChoiceChip(
                label: 'نشطة',
                selected: status == AppStatuses.active,
                onTap: () => onStatusChanged(AppStatuses.active),
              ),
              AppChoiceChip(
                label: 'ملغاة',
                selected: status == AppStatuses.cancelled,
                onTap: () => onStatusChanged(AppStatuses.cancelled),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacing16),
          _ScopeFilters(
            center: center,
            branch: branch,
            envelope: envelope,
            onCenterChanged: onCenterChanged,
            onBranchChanged: onBranchChanged,
            onEnvelopeChanged: onEnvelopeChanged,
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacing16),
            DropdownButtonFormField<String>(
              key: ValueKey('category-$categoryValue'),
              initialValue: categoryValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'التصنيف',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: _Filter.all,
                  child: Text('كل التصنيفات'),
                ),
                for (final item in categories)
                  DropdownMenuItem(
                    value: item,
                    child: Text(
                      _categoryLabel(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (next) {
                if (next != null) onCategoryChanged(next);
              },
            ),
          ],
          if (hasActiveFilters) ...[
            const SizedBox(height: AppDimensions.spacing8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('مسح الفلاتر'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// فلاتر المركز والفرع والظرف المالي (مع خيار «الكل»): الأسماء تُقرأ من
/// centers / branches / fundEnvelopes، وقائمة الفروع تُحصر بالمركز المختار.
class _ScopeFilters extends StatefulWidget {
  const _ScopeFilters({
    required this.center,
    required this.branch,
    required this.envelope,
    required this.onCenterChanged,
    required this.onBranchChanged,
    required this.onEnvelopeChanged,
  });

  final String center;
  final String branch;
  final String envelope;
  final ValueChanged<String> onCenterChanged;
  final ValueChanged<String> onBranchChanged;
  final ValueChanged<String> onEnvelopeChanged;

  @override
  State<_ScopeFilters> createState() => _ScopeFiltersState();
}

class _ScopeFiltersState extends State<_ScopeFilters> {
  // مستمعات تُنشأ مرة واحدة (لا تُعاد عند كل إعادة بناء للصفحة).
  late final _centersStream = FirebaseFirestore.instance
      .collection(AppCollections.centers)
      .snapshots();
  late final _branchesStream = FirebaseFirestore.instance
      .collection(AppCollections.branches)
      .snapshots();
  late final _envelopesStream = FirebaseFirestore.instance
      .collection(AppCollections.fundEnvelopes)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    final center = widget.center;
    final branch = widget.branch;
    final envelope = widget.envelope;
    final onCenterChanged = widget.onCenterChanged;
    final onBranchChanged = widget.onBranchChanged;
    final onEnvelopeChanged = widget.onEnvelopeChanged;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _centersStream,
      builder: (context, centersSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _branchesStream,
          builder: (context, branchesSnap) {
            final centers = (centersSnap.data?.docs ?? const [])
                .map(CenterModel.fromSnapshot)
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            final branches = (branchesSnap.data?.docs ?? const [])
                .map(BranchModel.fromSnapshot)
                .where((item) => center == _Filter.all || item.centerId == center)
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            final centerValue =
                center == _Filter.all || centers.any((c) => c.id == center)
                    ? center
                    : _Filter.all;
            final branchValue =
                branch == _Filter.all || branches.any((b) => b.id == branch)
                    ? branch
                    : _Filter.all;

            final centerField = DropdownButtonFormField<String>(
              key: ValueKey('center-$centerValue'),
              initialValue: centerValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المركز',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: _Filter.all,
                  child: Text('الكل'),
                ),
                for (final item in centers)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (next) {
                if (next != null) onCenterChanged(next);
              },
            );

            final branchField = DropdownButtonFormField<String>(
              key: ValueKey('branch-$centerValue-$branchValue'),
              initialValue: branchValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الفرع',
                prefixIcon: Icon(Icons.store_mall_directory_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: _Filter.all,
                  child: Text('الكل'),
                ),
                for (final item in branches)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (next) {
                if (next != null) onBranchChanged(next);
              },
            );

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _envelopesStream,
              builder: (context, envelopesSnap) {
                final envelopes = (envelopesSnap.data?.docs ?? const [])
                    .map(EnvelopeModel.fromSnapshot)
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));
                final envelopeValue = envelope == _Filter.all ||
                        envelopes.any((e) => e.id == envelope)
                    ? envelope
                    : _Filter.all;

                final envelopeField = DropdownButtonFormField<String>(
                  key: ValueKey('envelope-filter-$envelopeValue'),
                  initialValue: envelopeValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الظرف المالي',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _Filter.all,
                      child: Text('الكل'),
                    ),
                    for (final item in envelopes)
                      DropdownMenuItem(
                        value: item.id,
                        child:
                            Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (next) {
                    if (next != null) onEnvelopeChanged(next);
                  },
                );

                return AppResponsiveGrid(
                  minItemWidth: 220,
                  maxColumns: 3,
                  children: [centerField, branchField, envelopeField],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// القائمة المجمعة حسب اليوم
// ─────────────────────────────────────────────────────────────────────────────

class _DayGroup {
  _DayGroup(this.day);

  final DateTime day;
  final List<TransactionModel> items = [];

  /// صافي اليوم (الحركات النشطة فقط).
  num get net => items
      .where((item) => item.status == AppStatuses.active)
      .fold<num>(
        0,
        (value, item) => item.type == AppTransactionTypes.income
            ? value + item.amount
            : value - item.amount,
      );
}

List<_DayGroup> _groupByDay(List<TransactionModel> items) {
  final groups = <String, _DayGroup>{};
  for (final item in items) {
    final d = item.createdAt;
    final key = '${d.year}-${d.month}-${d.day}';
    groups.putIfAbsent(key, () => _DayGroup(DateTime(d.year, d.month, d.day)))
        .items
        .add(item);
  }
  return groups.values.toList();
}

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'أمس';
  return AppFormatters.date(day);
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.group,
    required this.canCancel,
    required this.cancellingId,
    required this.onCancel,
  });

  final _DayGroup group;
  final bool canCancel;
  final String? cancellingId;
  final ValueChanged<TransactionModel> onCancel;

  @override
  Widget build(BuildContext context) {
    final net = group.net;
    final netColor = net > 0
        ? AppColors.income
        : net < 0
            ? AppColors.expense
            : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: AppDimensions.spacing4,
              bottom: AppDimensions.spacing8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dayLabel(group.day),
                    style: AppTypography.titleMedium,
                  ),
                ),
                Text(
                  AppFormatters.amountSigned(net, showSign: true),
                  style: AppTypography.titleMedium.copyWith(color: netColor),
                ),
              ],
            ),
          ),
          AppCard(
            elevated: true,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              child: Column(
                children: [
                  for (var i = 0; i < group.items.length; i++) ...[
                    _TransactionTile(
                      transaction: group.items[i],
                      canCancel: canCancel,
                      cancelling: cancellingId == group.items[i].id,
                      busy: cancellingId != null,
                      onCancel: () => onCancel(group.items[i]),
                    ),
                    if (i != group.items.length - 1)
                      const Divider(
                        indent: AppDimensions.cardPadding,
                        endIndent: AppDimensions.cardPadding,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatefulWidget {
  const _TransactionTile({
    required this.transaction,
    required this.canCancel,
    required this.cancelling,
    required this.busy,
    required this.onCancel,
  });

  final TransactionModel transaction;
  final bool canCancel;

  /// هذه البطاقة هي التي يجري إلغاؤها الآن (يظهر مؤشر التحميل فيها فقط).
  final bool cancelling;

  /// هناك إلغاء جارٍ في بطاقة ما: تُعطَّل قوائم البقية دون مؤشر.
  final bool busy;
  final VoidCallback onCancel;

  @override
  State<_TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<_TransactionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final income = transaction.type == AppTransactionTypes.income;
    final cancelled = transaction.status == AppStatuses.cancelled;
    final color = income ? AppColors.income : AppColors.expense;
    final time = AppFormatters.toWesternDigits(
      TimeOfDay.fromDateTime(transaction.createdAt).format(context),
    );

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.cardPadding,
          vertical: AppDimensions.spacing12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppIconBadge(
                  icon: income
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: cancelled ? AppColors.disabled : color,
                  background:
                      cancelled ? AppColors.surfaceAlt : color.withAlpha(28),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleFor(transaction),
                        style: AppTypography.titleMedium.copyWith(
                          color: cancelled ? AppColors.textSecondary : null,
                          decoration:
                              cancelled ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spacing2),
                      Text(
                        '${_categoryLabel(transaction.category)} • $time',
                        style: AppTypography.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cancelled) ...[
                        const SizedBox(height: AppDimensions.spacing4),
                        const AppStatusChip(
                          label: 'ملغاة',
                          color: AppColors.error,
                          backgroundColor: AppColors.errorLight,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing8),
                if (cancelled)
                  Text(
                    AppFormatters.amount(transaction.amount),
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  )
                else
                  AppAmountText(amount: transaction.amount, isIncome: income),
                if (widget.canCancel && !cancelled)
                  widget.cancelling
                      ? const Padding(
                          padding: EdgeInsets.all(AppDimensions.spacing12),
                          child: SizedBox(
                            width: AppDimensions.iconSmall,
                            height: AppDimensions.iconSmall,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : PopupMenuButton<String>(
                          enabled: !widget.busy,
                          tooltip: 'خيارات',
                          icon: const Icon(Icons.more_vert_rounded),
                          onSelected: (_) => widget.onCancel(),
                          itemBuilder: (_) => const [
                            PopupMenuItem<String>(
                              value: 'cancel',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.cancel_outlined,
                                    color: AppColors.error,
                                  ),
                                  SizedBox(width: AppDimensions.spacing8),
                                  Text('إلغاء الحركة'),
                                ],
                              ),
                            ),
                          ],
                        ),
              ],
            ),
            AnimatedSize(
              duration: AppDurations.fast,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _TransactionDetails(transaction: transaction)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionDetails extends StatelessWidget {
  const _TransactionDetails({required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final income = transaction.type == AppTransactionTypes.income;
    final notes = transaction.notes.trim();

    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.spacing12),
      padding: const EdgeInsets.all(AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInfoRow(label: 'النوع', value: income ? 'إيراد' : 'مصروف'),
          AppInfoRow(
            label: 'التصنيف',
            value: _categoryLabel(transaction.category),
          ),
          AppInfoRow(
            label: 'طريقة الدفع',
            value: _paymentLabel(transaction.paymentMethod),
          ),
          AppInfoRow(
            label: 'التاريخ',
            value: AppFormatters.dateTime(transaction.createdAt),
          ),
          if (notes.isNotEmpty) AppInfoRow(label: 'الملاحظات', value: notes),
        ],
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  final bool hasActiveFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing32),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: AppDimensions.spacing48,
              color: AppColors.disabled,
            ),
            const SizedBox(height: AppDimensions.spacing12),
            Text(
              hasActiveFilters
                  ? 'لا توجد حركات مطابقة للبحث أو الفلاتر'
                  : 'لا توجد حركات مسجلة بعد',
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: AppDimensions.spacing12),
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('مسح الفلاتر'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _paymentLabel(String method) {
  switch (method) {
    case AppPaymentMethods.cash:
      return 'نقدي';
    case AppPaymentMethods.vodafoneCash:
      return 'فودافون كاش';
    case AppPaymentMethods.bankTransfer:
      return 'تحويل بنكي';
    case AppPaymentMethods.cheque:
      return 'شيك';
    case AppPaymentMethods.other:
      return 'أخرى';
    default:
      return method.isEmpty ? '—' : method;
  }
}

class _CreateTransactionDialog extends StatefulWidget {
  const _CreateTransactionDialog();

  @override
  State<_CreateTransactionDialog> createState() =>
      _CreateTransactionDialogState();
}

class _CreateTransactionDialogState extends State<_CreateTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  /// معرّف واحد لنافذة الإضافة: يُستخدم في المحاولة المباشرة والمسودة معًا،
  /// فإن ضاع الرد بعد التزام ناجح لا تتكرر الحركة عند المزامنة.
  final String _requestId = const Uuid().v4();
  String _type = AppTransactionTypes.income;
  String? _category;
  String? _envelopeId;
  String _centerId = _Filter.all;
  String _branchId = _Filter.all;
  String _paymentMethod = AppPaymentMethods.cash;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static EnvelopeModel? _envelopeById(List<EnvelopeModel> envelopes, String? id) {
    for (final item in envelopes) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// الظرف المخصص يحصر المصروفات في بنود الصرف المسموحة له فقط
  /// (الإيرادات غير مقيدة، وسلف الموظفين تُنشأ آليًا فلا تُعرض يدويًا).
  bool _isRestrictedExpense(EnvelopeModel? envelope) =>
      envelope != null &&
      envelope.fundType == AppFundTypes.restricted &&
      _type == AppTransactionTypes.expense;

  List<String> _categoriesFor(EnvelopeModel? envelope) {
    if (_type == AppTransactionTypes.income) {
      return AppIncomeCategories.creatable;
    }
    if (_isRestrictedExpense(envelope)) {
      return envelope!.allowedExpenseCategories
          .where((item) => item != AppExpenseCategories.employeeLoan)
          .toList();
    }
    return AppExpenseCategories.creatable;
  }

  Future<void> _save(List<EnvelopeModel> envelopes) async {
    if (!_formKey.currentState!.validate()) return;
    final envelopeIndex =
        envelopes.indexWhere((item) => item.id == _envelopeId);
    final envelope = envelopeIndex == -1 ? null : envelopes[envelopeIndex];
    if (envelope == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر ظرفًا ماليًا صالحًا.')),
      );
      return;
    }
    final amount =
        double.parse(_amountController.text.trim().replaceAll(',', ''));
    if (_type == AppTransactionTypes.expense &&
        amount > envelope.currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'الرصيد المتاح في «${envelope.name}» هو ${AppFormatters.amount(envelope.currentBalance)}.'),
        ),
      );
      return;
    }

    final isIncome = _type == AppTransactionTypes.income;
    final amountText = AppFormatters.amount(amount);
    final confirmed = await showAppConfirmDialog(
      context,
      title: sl<ConnectivityService>().isOnline
          ? AppStrings.confirmAction
          : 'حفظ كمسودة حركة معلقة',
      message: sl<ConnectivityService>().isOnline
          ? 'سيتم تسجيل ${isIncome ? 'إيراد' : 'مصروف'} بمبلغ $amountText ج.م '
              '(${_nameController.text.trim()}) ${isIncome ? 'في' : 'من'} '
              'الظرف «${envelope.name}»، وسيتغيّر رصيده فورًا. '
              'هل تريد المتابعة؟'
          : 'أنت غير متصل بالإنترنت. ستُحفظ الحركة كمسودة على هذا الجهاز '
              'ولن يتغيّر رصيد الظرف حتى تتوفر الشبكة وتتم المزامنة '
              '(وقد تُرفض حينها إن لم يعد الرصيد كافيًا). هل تريد المتابعة؟',
      confirmLabel: sl<ConnectivityService>().isOnline
          ? (isIncome ? 'تسجيل الإيراد' : 'تسجيل المصروف')
          : 'حفظ كمسودة',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final outcome = await sl<OperationSubmitter>().submit(
        handler: const CreateTransactionHandler(),
        requestId: _requestId,
        title: '${_type == AppTransactionTypes.income ? 'إيراد' : 'مصروف'}: '
            '${_nameController.text.trim()} (${AppFormatters.amount(amount)})',
        payload: {
          'envelopeId': envelope.id,
          // «الكل» = بلا اختيار: يبقى مركز الظرف ويُترك الفرع فارغًا.
          'centerId': _centerId == _Filter.all ? null : _centerId,
          'branchId': _centerId == _Filter.all || _branchId == _Filter.all
              ? null
              : _branchId,
          'type': _type,
          'category': _category,
          'name': _nameController.text.trim(),
          'amount': amount,
          'paymentMethod': _paymentMethod,
          'forMonth': null,
          'notes': _notesController.text.trim(),
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome == SubmitOutcome.sent
                  ? 'تم تسجيل الحركة وتحديث رصيد الظرف.'
                  : 'حُفظت الحركة كمسودة معلّقة على هذا الجهاز وتُرسل تلقائيًا '
                      'عند توفر الاتصال (ولن تتكرر).',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الحركة: ${ErrorText.of(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('إضافة حركة مالية'),
        content: SizedBox(
          width: 460,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(AppCollections.fundEnvelopes)
                .where('status', isEqualTo: AppStatuses.active)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('تعذر تحميل الأظرف: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final envelopes = snapshot.data!.docs
                  .map(EnvelopeModel.fromSnapshot)
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              if (envelopes.isEmpty) {
                return const Text('أنشئ ظرفًا ماليًا نشطًا أولًا لإضافة حركة.');
              }
              final selectedEnvelope = _envelopeById(envelopes, _envelopeId);
              final categories = _categoriesFor(selectedEnvelope);
              final restrictedExpense = _isRestrictedExpense(selectedEnvelope);
              return SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'نوع الحركة',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: AppTransactionTypes.income,
                            child: Text('إيراد')),
                        DropdownMenuItem(
                            value: AppTransactionTypes.expense,
                            child: Text('مصروف')),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                                _type = value!;
                                _category = null;
                              }),
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('envelope-$_envelopeId'),
                      initialValue: _envelopeId,
                      decoration: const InputDecoration(
                        labelText: 'الظرف المالي',
                        border: OutlineInputBorder(),
                      ),
                      items: envelopes
                          .map((item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                    '${item.name} — ${AppFormatters.amount(item.currentBalance)}'),
                              ))
                          .toList(),
                      validator: (value) => value == null ? 'اختر الظرف' : null,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                                _envelopeId = value;
                                final allowed = _categoriesFor(
                                    _envelopeById(envelopes, value));
                                if (_category != null &&
                                    !allowed.contains(_category)) {
                                  _category = null;
                                }
                              }),
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    _CenterBranchFormFields(
                      center: _centerId,
                      branch: _branchId,
                      enabled: !_saving,
                      onCenterChanged: (value) => setState(() {
                        _centerId = value;
                        _branchId = _Filter.all;
                      }),
                      onBranchChanged: (value) =>
                          setState(() => _branchId = value),
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('category-$_type-$_envelopeId-$_category'),
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: 'التصنيف',
                        helperText: !restrictedExpense
                            ? null
                            : categories.isEmpty
                                ? 'لا توجد بنود صرف مسموحة لهذا الظرف'
                                : 'الظرف مخصص: تظهر بنود الصرف المسموحة له فقط',
                        border: const OutlineInputBorder(),
                      ),
                      items: categories
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(_categoryLabel(item)),
                              ))
                          .toList(),
                      validator: (value) =>
                          value == null ? 'اختر التصنيف' : null,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _category = value),
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'اسم الحركة',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().length < 3
                              ? 'أدخل اسمًا من 3 أحرف على الأقل'
                              : null,
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    TextFormField(
                      controller: _amountController,
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ بالجنيه',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(
                            value?.trim().replaceAll(',', '') ?? '');
                        return amount == null || amount <= 0
                            ? 'أدخل مبلغًا أكبر من صفر'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع / التحصيل',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: AppPaymentMethods.cash, child: Text('نقدي')),
                        DropdownMenuItem(
                            value: AppPaymentMethods.vodafoneCash,
                            child: Text('فودافون كاش')),
                        DropdownMenuItem(
                            value: AppPaymentMethods.bankTransfer,
                            child: Text('تحويل بنكي')),
                        DropdownMenuItem(
                            value: AppPaymentMethods.cheque,
                            child: Text('شيك')),
                        DropdownMenuItem(
                            value: AppPaymentMethods.other,
                            child: Text('أخرى')),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _paymentMethod = value!),
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    TextFormField(
                      controller: _notesController,
                      enabled: !_saving,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(AppCollections.fundEnvelopes)
                .where('status', isEqualTo: AppStatuses.active)
                .snapshots(),
            builder: (context, snapshot) => FilledButton(
              onPressed: _saving || !snapshot.hasData
                  ? null
                  : () => _save(snapshot.data!.docs
                      .map(EnvelopeModel.fromSnapshot)
                      .toList()),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ الحركة'),
            ),
          ),
        ],
      );
}

/// حقلا المركز والفرع في نموذج إضافة حركة (خيار «الكل» = بلا تحديد).
/// الفرع يُفعَّل بعد اختيار مركز، وقائمته محصورة بفروع ذلك المركز.
class _CenterBranchFormFields extends StatelessWidget {
  const _CenterBranchFormFields({
    required this.center,
    required this.branch,
    required this.enabled,
    required this.onCenterChanged,
    required this.onBranchChanged,
  });

  final String center;
  final String branch;
  final bool enabled;
  final ValueChanged<String> onCenterChanged;
  final ValueChanged<String> onBranchChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppCollections.centers)
          .snapshots(),
      builder: (context, centersSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppCollections.branches)
              .snapshots(),
          builder: (context, branchesSnap) {
            final centers = (centersSnap.data?.docs ?? const [])
                .map(CenterModel.fromSnapshot)
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            final branches = (branchesSnap.data?.docs ?? const [])
                .map(BranchModel.fromSnapshot)
                .where((item) => item.centerId == center)
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            final centerValue =
                center == _Filter.all || centers.any((c) => c.id == center)
                    ? center
                    : _Filter.all;
            final branchValue =
                branch == _Filter.all || branches.any((b) => b.id == branch)
                    ? branch
                    : _Filter.all;
            final hasCenter = centerValue != _Filter.all;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('form-center-$centerValue'),
                  initialValue: centerValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المركز',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _Filter.all,
                      child: Text('الكل'),
                    ),
                    for (final item in centers)
                      DropdownMenuItem(
                        value: item.id,
                        child:
                            Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: enabled
                      ? (next) {
                          if (next != null) onCenterChanged(next);
                        }
                      : null,
                ),
                const SizedBox(height: AppDimensions.spacing12),
                DropdownButtonFormField<String>(
                  key: ValueKey('form-branch-$centerValue-$branchValue'),
                  initialValue: branchValue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'الفرع',
                    helperText: hasCenter ? null : 'اختر مركزًا لعرض فروعه',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _Filter.all,
                      child: Text('الكل'),
                    ),
                    for (final item in branches)
                      DropdownMenuItem(
                        value: item.id,
                        child:
                            Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: enabled && hasCenter
                      ? (next) {
                          if (next != null) onBranchChanged(next);
                        }
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

abstract class _Filter {
  static const all = 'all';
}

String _titleFor(TransactionModel transaction) {
  if (transaction.name?.trim().isNotEmpty == true) {
    return transaction.name!.trim();
  }
  if (transaction.notes.trim().isNotEmpty) {
    return transaction.notes.trim();
  }
  return _categoryLabel(transaction.category);
}

String _categoryLabel(String category) {
  switch (category) {
    case AppIncomeCategories.studentSubscription:
      return 'اشتراكات الطلاب';
    case AppIncomeCategories.donation:
      return 'تبرعات';
    case AppIncomeCategories.loanRepayment:
      return 'سداد سلفة';
    case AppIncomeCategories.openingBalance:
      return 'رصيد افتتاحي';
    case AppIncomeCategories.otherIncome:
      return 'إيراد آخر';
    case AppExpenseCategories.employeeLoan:
      return 'سلفة موظف';
    case AppExpenseCategories.salaries:
      return 'رواتب';
    case AppExpenseCategories.rent:
      return 'إيجار';
    case AppExpenseCategories.utilities:
      return 'مرافق';
    case AppExpenseCategories.maintenance:
      return 'صيانة';
    case AppExpenseCategories.supplies:
      return 'مستلزمات';
    case AppExpenseCategories.quranCopiesPurchase:
      return 'شراء مصاحف';
    case AppExpenseCategories.fansPurchase:
      return 'شراء مراوح';
    case AppExpenseCategories.otherExpense:
      return 'مصروف آخر';
    default:
      return category.isEmpty ? 'حركة مالية' : category;
  }
}
