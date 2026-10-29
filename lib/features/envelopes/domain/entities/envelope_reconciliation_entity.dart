import 'package:equatable/equatable.dart';

/// بند تسوية ومطابقة لظرف مالي واحد.
class EnvelopeReconciliationItem extends Equatable {
  const EnvelopeReconciliationItem({
    required this.envelopeId,
    required this.envelopeName,
    required this.currentBalance,
    required this.calculatedBalance,
    required this.transactionCount,
    required this.isMatched,
    required this.discrepancy,
  });

  final String envelopeId;
  final String envelopeName;
  final double currentBalance;
  final double calculatedBalance;
  final int transactionCount;
  final bool isMatched;
  final double discrepancy;

  @override
  List<Object?> get props => [
        envelopeId,
        envelopeName,
        currentBalance,
        calculatedBalance,
        transactionCount,
        isMatched,
        discrepancy,
      ];
}

/// تقرير التسوية والمطابقة الشامل لجميع الأظرف المالية.
class EnvelopeReconciliationResult extends Equatable {
  const EnvelopeReconciliationResult({
    required this.items,
    required this.reconciledAt,
  });

  final List<EnvelopeReconciliationItem> items;
  final DateTime reconciledAt;

  int get totalEnvelopes => items.length;
  int get matchedCount => items.where((item) => item.isMatched).length;
  int get discrepancyCount => items.where((item) => !item.isMatched).length;
  bool get hasDiscrepancy => discrepancyCount > 0;

  double get totalCurrentBalance =>
      items.fold(0.0, (sum, item) => sum + item.currentBalance);

  double get totalCalculatedBalance =>
      items.fold(0.0, (sum, item) => sum + item.calculatedBalance);

  @override
  List<Object?> get props => [items, reconciledAt];
}
