import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/envelope_form_params.dart';
import '../bloc/envelopes_bloc.dart';

/// نافذة التحويل بين ظرفين.
///
/// التحقق المحلي (المبلغ > 0 و<= رصيد المصدر) لتحسين التجربة فقط،
/// والتحقق النهائي من الرصيد والصلاحيات يتم على الخادم.
class EnvelopeTransferSheet extends StatefulWidget {
  const EnvelopeTransferSheet({super.key});

  @override
  State<EnvelopeTransferSheet> createState() => _EnvelopeTransferSheetState();
}

class _EnvelopeTransferSheetState extends State<EnvelopeTransferSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _fromEnvelopeId;
  String? _toEnvelopeId;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<EnvelopesBloc>();
    final active = bloc.state.activeEnvelopes;
    if (active.isNotEmpty) {
      _fromEnvelopeId = active.first.id;
      if (active.length >= 2) _toEnvelopeId = active[1].id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  EnvelopeEntity? _findEnvelope(List<EnvelopeEntity> envelopes, String? id) {
    if (id == null) return null;
    for (final e in envelopes) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bloc = context.read<EnvelopesBloc>();
    final from = _findEnvelope(bloc.state.activeEnvelopes, _fromEnvelopeId);
    final to = _findEnvelope(bloc.state.activeEnvelopes, _toEnvelopeId);
    if (from == null || to == null || from.id == to.id) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    if (amount == null || amount <= 0) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'تأكيد التحويل',
      message:
          'سيتم تحويل ${AppFormatters.amount(amount)} من الظرف "${from.name}" '
          'إلى الظرف "${to.name}". التحويل داخلي لا يُعد إيرادًا أو مصروفًا '
          'للخزنة. هل تريد المتابعة؟',
      confirmLabel: 'تنفيذ التحويل',
    );
    if (!confirmed || !mounted) return;

    bloc.add(EnvelopesTransferRequested(TransferParams(
      fromEnvelopeId: from.id,
      toEnvelopeId: to.id,
      amount: amount,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    )));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EnvelopesBloc, EnvelopesState>(
      builder: (context, state) {
        final active = state.activeEnvelopes;
        final isSubmitting = state.isSubmitting;
        final from = _findEnvelope(active, _fromEnvelopeId);
        final targets = active.where((e) => e.id != _fromEnvelopeId).toList();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.cardPaddingLarge),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: AppDimensions.bottomSheetHandleWidth,
                      height: AppDimensions.bottomSheetHandleHeight,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),
                  const Text(
                    'تحويل بين الأظرف',
                    style: AppTypography.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacing4),
                  const Text(
                    'تحويل داخلي بين ظرفين — لا يُسجل إيرادًا أو مصروفًا للخزنة',
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),

                  // ظرف المصدر
                  AppDropdownField<String>(
                    label: 'ظرف المصدر *',
                    items: active
                        .map((e) => DropdownMenuItem<String>(
                              value: e.id,
                              child: Text(
                                '${e.name} — ${AppFormatters.amountCompact(e.currentBalance)}',
                              ),
                            ))
                        .toList(),
                    value: from?.id,
                    hint: active.isEmpty ? 'لا توجد أظرف نشطة' : 'اختر الظرف',
                    enabled: !isSubmitting && active.isNotEmpty,
                    validator: (v) => v == null ? 'ظرف المصدر مطلوب' : null,
                    onChanged: (v) => setState(() {
                      _fromEnvelopeId = v;
                      if (_toEnvelopeId == v) _toEnvelopeId = null;
                    }),
                  ),

                  // الرصيد المتاح للمصدر
                  if (from != null) ...[
                    const SizedBox(height: AppDimensions.spacing8),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacing12),
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMedium,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: AppDimensions.iconMedium,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: AppDimensions.spacing8),
                          Expanded(
                            child: Text(
                              'الرصيد المتاح في "${from.name}": '
                              '${AppFormatters.amount(from.currentBalance)}',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimensions.itemSpacing),

                  // الظرف الهدف (يستثني المصدر)
                  AppDropdownField<String>(
                    label: 'الظرف الهدف *',
                    items: targets
                        .map((e) => DropdownMenuItem<String>(
                              value: e.id,
                              child: Text(
                                '${e.name} — ${AppFormatters.amountCompact(e.currentBalance)}',
                              ),
                            ))
                        .toList(),
                    value: targets.any((e) => e.id == _toEnvelopeId)
                        ? _toEnvelopeId
                        : null,
                    hint: targets.isEmpty
                        ? 'لا يوجد ظرف آخر نشط'
                        : 'اختر الظرف الهدف',
                    enabled: !isSubmitting && targets.isNotEmpty,
                    validator: (v) => v == null ? 'الظرف الهدف مطلوب' : null,
                    onChanged: (v) => setState(() => _toEnvelopeId = v),
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),

                  // المبلغ
                  AppTextField(
                    label: '${AppStrings.amount} (ج.م) *',
                    controller: _amountController,
                    hintText: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: !isSubmitting,
                    validator: (v) {
                      final base = AppValidators.amount(v);
                      if (base != null) return base;
                      final parsed = double.tryParse(
                        v?.trim().replaceAll(',', '') ?? '',
                      );
                      if (from != null &&
                          parsed != null &&
                          Money.fromUnits(parsed) >
                              Money.fromUnits(from.currentBalance)) {
                        return 'المبلغ يتجاوز رصيد الظرف المصدر '
                            '(${AppFormatters.amountCompact(from.currentBalance)})';
                      }
                      return null;
                    },
                    helperText: 'يتحقق الخادم نهائيًا من كفاية الرصيد',
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),

                  // ملاحظات
                  AppTextField(
                    label: AppStrings.notes,
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 1000,
                    enabled: !isSubmitting,
                    validator: AppValidators.notes,
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),

                  AppButton(
                    label: 'تنفيذ التحويل',
                    onPressed: (from == null || targets.isEmpty || isSubmitting)
                        ? null
                        : _submit,
                    isLoading: isSubmitting,
                    icon: Icons.swap_horiz_rounded,
                  ),
                  const SizedBox(height: AppDimensions.spacing8),
                  AppButton(
                    label: AppStrings.cancel,
                    variant: AppButtonVariant.text,
                    onPressed:
                        isSubmitting ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: AppDimensions.spacing8),
                  const Text(
                    AppStrings.serverOnlyWarning,
                    style: AppTypography.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
