import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/envelope_transaction_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_amount_text.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/usecases/envelopes_usecases.dart';

/// صفحة سجل حركات ظرف مالي معين (envelopeId من مسار الصفحة).
/// قراءة فقط — حركات الأظرف تُنشأ من الخادم ولا يمكن تعديلها من العميل.
class EnvelopeTransactionsPage extends StatefulWidget {
  const EnvelopeTransactionsPage({required this.envelopeId, super.key});

  final String envelopeId;

  @override
  State<EnvelopeTransactionsPage> createState() =>
      _EnvelopeTransactionsPageState();
}

class _EnvelopeTransactionsPageState extends State<EnvelopeTransactionsPage> {
  bool _isLoading = true;
  String? _failure;
  List<EnvelopeTransactionEntity> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    final result = await sl<GetEnvelopeTransactions>().call(widget.envelopeId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _isLoading = false;
        _failure = failure.message;
      }),
      (transactions) => setState(() {
        _isLoading = false;
        _transactions = transactions;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل حركات الظرف')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingView(message: AppStrings.loading);
    }
    if (_failure != null) {
      return AppErrorView(message: _failure!, onRetry: _loadTransactions);
    }
    if (_transactions.isEmpty) {
      return const AppEmptyView(
        message: 'لا توجد حركات على هذا الظرف بعد',
        icon: Icons.receipt_long_outlined,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppDimensions.pagePaddingMobile),
          itemCount: _transactions.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppDimensions.itemSpacing),
          itemBuilder: (context, index) => _EnvelopeTransactionTile(
            transaction: _transactions[index],
          ),
        ),
      ),
    );
  }
}

class _EnvelopeTransactionTile extends StatelessWidget {
  const _EnvelopeTransactionTile({required this.transaction});

  final EnvelopeTransactionEntity transaction;

  String get _typeLabel {
    switch (transaction.type) {
      case AppEnvelopeTransactionTypes.income:
        return 'إيراد';
      case AppEnvelopeTransactionTypes.expense:
        return 'مصروف';
      case AppEnvelopeTransactionTypes.allocation:
        return 'تخصيص';
      case AppEnvelopeTransactionTypes.transferIn:
        return 'تحويل وارد';
      case AppEnvelopeTransactionTypes.transferOut:
        return 'تحويل صادر';
      case AppEnvelopeTransactionTypes.refund:
        return 'استرداد';
      case AppEnvelopeTransactionTypes.adjustment:
        return 'تسوية';
      default:
        return transaction.type;
    }
  }

  /// التصنيف اللوني الدلالي لنوع الحركة (ألوان الهوية فقط).
  (Color, IconData) get _typeStyle {
    switch (transaction.type) {
      case AppEnvelopeTransactionTypes.income:
      case AppEnvelopeTransactionTypes.refund:
      case AppEnvelopeTransactionTypes.transferIn:
        return (AppColors.income, Icons.south_west_rounded);
      case AppEnvelopeTransactionTypes.expense:
      case AppEnvelopeTransactionTypes.transferOut:
        return (AppColors.expense, Icons.north_east_rounded);
      case AppEnvelopeTransactionTypes.allocation:
        return (AppColors.info, Icons.account_balance_wallet_outlined);
      case AppEnvelopeTransactionTypes.adjustment:
      default:
        return (AppColors.warning, Icons.tune_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (typeColor, typeIcon) = _typeStyle;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppDimensions.iconLarge + AppDimensions.spacing8,
            height: AppDimensions.iconLarge + AppDimensions.spacing8,
            decoration: BoxDecoration(
              color: typeColor.withAlpha(38),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Icon(typeIcon, color: typeColor),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AppStatusChip(
                      label: _typeLabel,
                      color: typeColor,
                      backgroundColor: typeColor.withAlpha(28),
                    ),
                    const Spacer(),
                    _AmountView(transaction: transaction),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing4),
                if (transaction.notes.trim().isNotEmpty)
                  Text(
                    transaction.notes,
                    style: AppTypography.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppDimensions.spacing4),
                Row(
                  children: [
                    Text(
                      AppFormatters.dateTime(transaction.createdAt),
                      style: AppTypography.labelSmall,
                    ),
                    const Spacer(),
                    if (transaction.transactionId != null &&
                        transaction.transactionId!.isNotEmpty)
                      Text(
                        'معرّف الحركة: ${transaction.transactionId}',
                        style: AppTypography.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// عرض المبلغ وفق نوع الحركة (ذات إشارة للمزيدة/المصروفية، محايد للتخصيص والتسوية).
class _AmountView extends StatelessWidget {
  const _AmountView({required this.transaction});

  final EnvelopeTransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    switch (transaction.type) {
      case AppEnvelopeTransactionTypes.income:
      case AppEnvelopeTransactionTypes.refund:
      case AppEnvelopeTransactionTypes.transferIn:
        return AppAmountText(
          amount: transaction.amount,
          isIncome: true,
        );
      case AppEnvelopeTransactionTypes.expense:
      case AppEnvelopeTransactionTypes.transferOut:
        return AppAmountText(
          amount: transaction.amount,
          isIncome: false,
        );
      case AppEnvelopeTransactionTypes.allocation:
        return AppNeutralAmountText(amount: transaction.amount);
      default:
        return AppNeutralAmountText(
          amount: transaction.amount,
          color: AppColors.warning,
        );
    }
  }
}
