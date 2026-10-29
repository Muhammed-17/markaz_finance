import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/data/models/envelope_model.dart';
import '../../../../core/data/models/transaction_model.dart';
import '../../../../core/services/categories_service.dart';
import '../../../../core/services/financial_operations_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_amount_text.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/month_field.dart' show categoryLabel;

/// سجل الحركات النقدية الفعلي؛ البحث والتصفية محليان لتجنب فهارس مركبة جديدة.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _searchController = TextEditingController();
  String _type = _Filter.all;
  String _status = _Filter.all;
  bool _cancelling = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionModel> _filtered(List<TransactionModel> source) {
    final search = _searchController.text.trim().toLowerCase();
    final items = source.where((item) {
      final haystack = '${item.name ?? ''} ${item.notes} ${item.category} '
              '${item.paymentMethod} ${item.id}'
          .toLowerCase();
      return (_type == _Filter.all || item.type == _type) &&
          (_status == _Filter.all || item.status == _status) &&
          (search.isEmpty || haystack.contains(search));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
              cancelling: _cancelling,
              canCreate:
                  PermissionService.can(profile, PermissionAction.create),
              canCancel:
                  PermissionService.can(profile, PermissionAction.cancel),
              onSearchChanged: () => setState(() {}),
              onTypeChanged: (value) => setState(() => _type = value),
              onStatusChanged: (value) => setState(() => _status = value),
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
    required this.cancelling,
    required this.canCreate,
    required this.canCancel,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onCreate,
    required this.onCancel,
  });

  final List<TransactionModel> all;
  final List<TransactionModel> visible;
  final TextEditingController searchController;
  final String type;
  final String status;
  final bool cancelling;
  final bool canCreate;
  final bool canCancel;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onCreate;
  final ValueChanged<TransactionModel> onCancel;

  @override
  Widget build(BuildContext context) {
    final active = all.where((item) => item.status == AppStatuses.active);
    final income = active
        .where((item) => item.type == AppTransactionTypes.income)
        .fold<num>(0, (value, item) => value + item.amount);
    final expense = active
        .where((item) => item.type == AppTransactionTypes.expense)
        .fold<num>(0, (value, item) => value + item.amount);
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
        child: ListView(
          padding: EdgeInsets.all(AppTypography.pagePaddingForWidth(width)),
          children: [
            Row(children: [
              const Expanded(
                child:
                    Text('الحركات المالية', style: AppTypography.headlineLarge),
              ),
              if (canCreate)
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة حركة'),
                ),
            ]),
            const SizedBox(height: AppDimensions.spacing4),
            const Text('سجل الإيرادات والمصروفات المسجلة في النظام.',
                style: AppTypography.bodySmall),
            const SizedBox(height: AppDimensions.sectionSpacing),
            _SummaryCards(income: income, expense: expense, count: all.length),
            const SizedBox(height: AppDimensions.sectionSpacing),
            _FiltersBar(
              searchController: searchController,
              type: type,
              status: status,
              onSearchChanged: onSearchChanged,
              onTypeChanged: onTypeChanged,
              onStatusChanged: onStatusChanged,
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Text('الحركات (${visible.length})',
                style: AppTypography.headlineSmall),
            const SizedBox(height: AppDimensions.spacing12),
            if (visible.isEmpty)
              const _EmptyTransactions()
            else
              ...visible.map((item) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: AppDimensions.itemSpacing),
                    child: _TransactionCard(
                      transaction: item,
                      canCancel: canCancel,
                      cancelling: cancelling,
                      onCancel: () => onCancel(item),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.income,
    required this.expense,
    required this.count,
  });
  final num income;
  final num expense;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryCard('إجمالي الإيرادات', AppFormatters.amount(income),
          AppColors.income, Icons.south_west_rounded),
      _SummaryCard('إجمالي المصروفات', AppFormatters.amount(expense),
          AppColors.expense, Icons.north_east_rounded),
      _SummaryCard('الرصيد الصافي', AppFormatters.amount(income - expense),
          AppColors.primary, Icons.account_balance_wallet_rounded),
      _SummaryCard('عدد الحركات', AppFormatters.integer(count), AppColors.info,
          Icons.receipt_long_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= AppDimensions.tabletBreakpoint
            ? 4
            : constraints.maxWidth >= AppDimensions.mobileBreakpoint
                ? 2
                : 1;
        final cardWidth =
            (constraints.maxWidth - AppDimensions.spacing12 * (columns - 1)) /
                columns;
        return Wrap(
          spacing: AppDimensions.spacing12,
          runSpacing: AppDimensions.spacing12,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.label, this.value, this.color, this.icon);
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacing8),
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTypography.labelMedium),
              const SizedBox(height: AppDimensions.spacing4),
              Text(value,
                  style: AppTypography.titleLarge.copyWith(color: color),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.type,
    required this.status,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });
  final TextEditingController searchController;
  final String type;
  final String status;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Wrap(
          spacing: AppDimensions.spacing12,
          runSpacing: AppDimensions.spacing12,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: searchController,
                onChanged: (_) => onSearchChanged(),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'ابحث بالاسم أو التصنيف أو الملاحظات',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            _FilterDropdown(
              value: type,
              label: 'النوع',
              items: const {
                _Filter.all: 'كل الأنواع',
                AppTransactionTypes.income: 'إيراد',
                AppTransactionTypes.expense: 'مصروف',
              },
              onChanged: onTypeChanged,
            ),
            _FilterDropdown(
              value: status,
              label: 'الحالة',
              items: const {
                _Filter.all: 'كل الحالات',
                AppStatuses.active: 'نشطة',
                AppStatuses.cancelled: 'ملغاة',
              },
              onChanged: onStatusChanged,
            ),
          ],
        ),
      );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });
  final String value;
  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 170,
        child: DropdownButtonFormField<String>(
          key: ValueKey(value),
          initialValue: value,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          items: items.entries
              .map((item) =>
                  DropdownMenuItem(value: item.key, child: Text(item.value)))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
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
  Widget build(BuildContext context) {
    final income = transaction.type == AppTransactionTypes.income;
    final cancelled = transaction.status == AppStatuses.cancelled;
    final color = income ? AppColors.income : AppColors.expense;
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: AppDimensions.spacing48,
          height: AppDimensions.spacing48,
          decoration: BoxDecoration(
            color: color.withAlpha(28),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: Icon(
            income ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: color,
          ),
        ),
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(_titleFor(transaction),
                      style: AppTypography.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              AppAmountText(amount: transaction.amount, isIncome: income),
            ]),
            const SizedBox(height: AppDimensions.spacing4),
            Wrap(
                spacing: AppDimensions.spacing8,
                runSpacing: AppDimensions.spacing4,
                children: [
                  AppStatusChip(
                      label: income ? 'إيراد' : 'مصروف',
                      color: color,
                      backgroundColor: color.withAlpha(28)),
                  AppStatusChip(
                      label: cancelled ? 'ملغاة' : 'نشطة',
                      color: cancelled ? AppColors.error : AppColors.success,
                      backgroundColor:
                          (cancelled ? AppColors.error : AppColors.success)
                              .withAlpha(28)),
                  if (transaction.category.isNotEmpty)
                    AppStatusChip(
                        label: _categoryLabel(transaction.category),
                        color: AppColors.textSecondary,
                        backgroundColor: AppColors.surfaceAlt),
                ]),
            if (transaction.notes.trim().isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacing8),
              Text(transaction.notes,
                  style: AppTypography.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: AppDimensions.spacing8),
            Row(children: [
              const Icon(Icons.schedule_rounded,
                  size: AppDimensions.iconSmall,
                  color: AppColors.textSecondary),
              const SizedBox(width: AppDimensions.spacing4),
              Expanded(
                  child: Text(AppFormatters.dateTime(transaction.createdAt),
                      style: AppTypography.labelSmall)),
              if (canCancel && !cancelled)
                TextButton.icon(
                  onPressed: cancelling ? null : onCancel,
                  icon: cancelling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined),
                  label: const Text('إلغاء'),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();
  @override
  Widget build(BuildContext context) => const AppCard(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.spacing32),
          child: Column(children: [
            Icon(Icons.receipt_long_outlined,
                size: AppDimensions.spacing48, color: AppColors.disabled),
            SizedBox(height: AppDimensions.spacing12),
            Text('لا توجد حركات مطابقة للبحث أو الفلاتر',
                style: AppTypography.bodyLarge),
          ]),
        ),
      );
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

  List<String> _categoriesFor(EnvelopeModel? envelope) {
    if (_type == AppTransactionTypes.income) {
      final customIncome = sl.isRegistered<CategoriesService>()
          ? sl<CategoriesService>().incomeCategories.map((c) => c.id).toList()
          : <String>[];
      return {...AppIncomeCategories.creatable, ...customIncome}.toList();
    }
    // إذا كان الظرف مخصصاً، يسمح فقط بالتصنيفات المحددة له
    if (envelope != null &&
        envelope.fundType == AppFundTypes.restricted &&
        envelope.allowedExpenseCategories.isNotEmpty) {
      return envelope.allowedExpenseCategories;
    }
    final customExpense = sl.isRegistered<CategoriesService>()
        ? sl<CategoriesService>().expenseCategories.map((c) => c.id).toList()
        : <String>[];
    return {...AppExpenseCategories.creatable, ...customExpense}.toList();
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
    if (_type == AppTransactionTypes.expense &&
        envelope.fundType == AppFundTypes.restricted &&
        !envelope.allowedExpenseCategories.contains(_category)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هذا الظرف مخصص ولا يسمح إلا بالتصنيفات التالية: '
            '${envelope.allowedExpenseCategories.map(_categoryLabel).join("، ")}',
          ),
        ),
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

              final selectedEnvelopeIndex =
                  envelopes.indexWhere((item) => item.id == _envelopeId);
              final selectedEnvelope = selectedEnvelopeIndex == -1
                  ? null
                  : envelopes[selectedEnvelopeIndex];
              final availableCategories = _categoriesFor(selectedEnvelope);

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
                                    '${item.name}${item.fundType == AppFundTypes.restricted ? " (مخصص)" : ""} — ${AppFormatters.amount(item.currentBalance)}'),
                              ))
                          .toList(),
                      validator: (value) => value == null ? 'اختر الظرف' : null,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                                _envelopeId = value;
                                final newEnv = envelopes.firstWhere(
                                  (e) => e.id == value,
                                  orElse: () => envelopes.first,
                                );
                                final allowed = _categoriesFor(newEnv);
                                if (_category != null && !allowed.contains(_category)) {
                                  _category = null;
                                }
                              }),
                    ),
                    const SizedBox(height: AppDimensions.spacing12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                          'category-$_type-$_envelopeId-$_category-${availableCategories.length}'),
                      initialValue: availableCategories.contains(_category)
                          ? _category
                          : null,
                      decoration: InputDecoration(
                        labelText: 'التصنيف',
                        helperText: _type == AppTransactionTypes.expense &&
                                selectedEnvelope?.fundType ==
                                    AppFundTypes.restricted
                            ? 'ظرف مخصص: محصور في بنود الصرف المحددة له فقط'
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      items: availableCategories
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
      if (category.isEmpty) return 'حركة مالية';
      return categoryLabel(category);
  }
}
