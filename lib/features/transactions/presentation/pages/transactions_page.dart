import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/data/models/envelope_model.dart';
import '../../../../core/data/models/transaction_model.dart';
import '../../../../core/services/financial_operations_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_amount_text.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_page_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

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
  bool _newestFirst = true;
  bool _cancelling = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _type != _Filter.all ||
      _status != _Filter.all ||
      _category != _Filter.all ||
      _searchController.text.trim().isNotEmpty;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _type = _Filter.all;
      _status = _Filter.all;
      _category = _Filter.all;
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
    setState(() => _cancelling = true);
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
          SnackBar(content: Text('تعذر إلغاء الحركة: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
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
        if (!PermissionService.can(profile, PermissionAction.view)) {
          return const AppErrorView(
            message: 'ليس لديك صلاحية عرض الحركات المالية.',
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(AppCollections.transactions)
              .snapshots(),
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
              newestFirst: _newestFirst,
              hasActiveFilters: _hasActiveFilters,
              cancelling: _cancelling,
              canCreate:
                  PermissionService.can(profile, PermissionAction.create),
              canCancel:
                  PermissionService.can(profile, PermissionAction.cancel),
              onSearchChanged: () => setState(() {}),
              onTypeChanged: (value) => setState(() => _type = value),
              onStatusChanged: (value) => setState(() => _status = value),
              onCategoryChanged: (value) => setState(() => _category = value),
              onToggleSort: () =>
                  setState(() => _newestFirst = !_newestFirst),
              onClearFilters: _clearFilters,
              onCreate: _showCreateTransaction,
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
    required this.newestFirst,
    required this.hasActiveFilters,
    required this.cancelling,
    required this.canCreate,
    required this.canCancel,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onToggleSort,
    required this.onClearFilters,
    required this.onCreate,
    required this.onCancel,
  });

  final List<TransactionModel> all;
  final List<TransactionModel> visible;
  final TextEditingController searchController;
  final String type;
  final String status;
  final String category;
  final bool newestFirst;
  final bool hasActiveFilters;
  final bool cancelling;
  final bool canCreate;
  final bool canCancel;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onToggleSort;
  final VoidCallback onClearFilters;
  final VoidCallback onCreate;
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

    final groups = _groupByDay(visible);

    return AppPageScroll(
      children: [
        AppPageHeader(
          title: 'الحركات المالية',
          subtitle: 'سجل الإيرادات والمصروفات المسجلة في النظام.',
          actions: [
            if (canCreate)
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة حركة'),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.sectionSpacing),
        _SummaryTiles(income: income, expense: expense, count: all.length),
        const SizedBox(height: AppDimensions.sectionSpacing),
        _FiltersCard(
          searchController: searchController,
          type: type,
          status: status,
          category: category,
          categories: categories,
          hasActiveFilters: hasActiveFilters,
          onSearchChanged: onSearchChanged,
          onTypeChanged: onTypeChanged,
          onStatusChanged: onStatusChanged,
          onCategoryChanged: onCategoryChanged,
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
              cancelling: cancelling,
              onCancel: onCancel,
            ),
        const SizedBox(height: AppDimensions.sectionSpacing),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// الملخص
// ─────────────────────────────────────────────────────────────────────────────

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
    return AppResponsiveGrid(
      minItemWidth: 240,
      children: [
        AppMetricTile(
          label: 'إجمالي الإيرادات',
          value: AppFormatters.amount(income),
          icon: Icons.south_west_rounded,
          color: AppColors.income,
          background: AppColors.incomeLight,
          valueColor: AppColors.income,
        ),
        AppMetricTile(
          label: 'إجمالي المصروفات',
          value: AppFormatters.amount(expense),
          icon: Icons.north_east_rounded,
          color: AppColors.expense,
          background: AppColors.expenseLight,
          valueColor: AppColors.expense,
        ),
        AppMetricTile(
          label: 'الرصيد الصافي',
          value: AppFormatters.amountSigned(net),
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.primary,
          background: AppColors.primaryLight,
          valueColor: net < 0 ? AppColors.expense : AppColors.primaryDark,
        ),
        AppMetricTile(
          label: 'عدد الحركات',
          value: AppFormatters.integer(count),
          icon: Icons.receipt_long_rounded,
          color: AppColors.info,
          background: AppColors.infoLight,
        ),
      ],
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
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final String type;
  final String status;
  final String category;
  final List<String> categories;
  final bool hasActiveFilters;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onCategoryChanged;
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
    required this.cancelling,
    required this.onCancel,
  });

  final _DayGroup group;
  final bool canCancel;
  final bool cancelling;
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
                      cancelling: cancelling,
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
    required this.onCancel,
  });

  final TransactionModel transaction;
  final bool canCancel;
  final bool cancelling;
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
  String _type = AppTransactionTypes.income;
  String? _category;
  String? _envelopeId;
  String _paymentMethod = AppPaymentMethods.cash;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> get _categories => _type == AppTransactionTypes.income
      ? AppIncomeCategories.creatable
      : AppExpenseCategories.creatable;

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

    setState(() => _saving = true);
    try {
      await sl<FinancialOperationsService>().call(
        AppFunctions.createTransaction,
        {
          'envelopeId': envelope.id,
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
          const SnackBar(content: Text('تم تسجيل الحركة وتحديث رصيد الظرف.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الحركة: $error')),
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
                          : (value) => setState(() => _envelopeId = value),
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('category-$_type-$_category'),
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
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
