import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/center_entity.dart';
import '../bloc/centers_bloc.dart';

/// BottomSheet نموذج إضافة/تعديل مركز.
///
/// يُستخدم للحالتين: [center] == null يعني إضافة، وإلا تعديل.
/// Bloc الصفحة (انظر CentersPage._openForm).
class CenterFormSheet extends StatefulWidget {
  const CenterFormSheet({this.center, super.key});

  final CenterEntity? center;

  @override
  State<CenterFormSheet> createState() => _CenterFormSheetState();
}

class _CenterFormSheetState extends State<CenterFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.center != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.center?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.center?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bloc = context.read<CentersBloc>();
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (_isEditing) {
      bloc.add(CentersUpdateRequested(
        id: widget.center!.id,
        name: name,
        description: description,
      ));
    } else {
      bloc.add(CentersAddRequested(name: name, description: description));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CentersBloc, CentersState>(
      // إغلاق الـ Sheet تلقائيًا عند نجاح العملية
      // (رسالة النجاح تعرضها صفحة القائمة عبر المستمع الخاص بها).
      listenWhen: (previous, current) =>
          current.status == CentersStatus.operationCompleted,
      listener: (listenerContext, state) => Navigator.of(listenerContext).pop(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.cardPaddingLarge),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing ? 'تعديل المركز' : 'إضافة مركز جديد',
                      style: AppTypography.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        size: AppDimensions.iconMedium),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing16),
              AppTextField(
                label: '${AppStrings.name} *',
                controller: _nameController,
                hintText: 'مثال: مركز النور للتحفيظ',
                prefixIcon: Icons.account_balance_rounded,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                validator: AppValidators.name,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              AppTextField(
                label: AppStrings.description,
                controller: _descriptionController,
                hintText: 'وصف اختياري للمركز',
                prefixIcon: Icons.notes_rounded,
                maxLines: 3,
                maxLength: 500,
                validator: AppValidators.description,
              ),
              const SizedBox(height: AppDimensions.spacing24),
              BlocBuilder<CentersBloc, CentersState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status,
                builder: (builderContext, state) {
                  final isSubmitting = state.status == CentersStatus.submitting;
                  return AppButton(
                    label: _isEditing ? AppStrings.save : AppStrings.add,
                    icon: _isEditing ? Icons.save_outlined : Icons.add_rounded,
                    onPressed: isSubmitting ? null : _submit,
                    isLoading: isSubmitting,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
