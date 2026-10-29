import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/branch_entity.dart';
import '../bloc/branches_bloc.dart';

/// BottomSheet نموذج إضافة/تعديل فرع.
///
/// يُستخدم للحالتين: [branch] == null يعني إضافة، وإلا تعديل.
/// قائمة المراكز مطلوبة للقائمة المنسدلة (centerId إلزامي).
/// Bloc الصفحة (انظر BranchesPage._openForm).
class BranchFormSheet extends StatefulWidget {
  const BranchFormSheet({
    required this.centers,
    this.branch,
    this.initialCenterId,
    super.key,
  });

  final BranchEntity? branch;

  /// المركز الابتدائي عند الإضافة (إن وُجد).
  final String? initialCenterId;

  /// خيارات المراكز المتاحة (محملة من صفحة القائمة).
  final List<CenterRef> centers;

  @override
  State<BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends State<BranchFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  String? _selectedCenterId;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.branch != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.branch?.name ?? '');
    _locationController =
        TextEditingController(text: widget.branch?.location ?? '');
    final initialCenterId = widget.branch?.centerId ?? widget.initialCenterId;
    final exists = widget.centers.any((center) => center.id == initialCenterId);
    _selectedCenterId = exists ? initialCenterId : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bloc = context.read<BranchesBloc>();
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final centerId = _selectedCenterId;
    if (centerId == null) return; // مدقق النموذج يمنع الوصول هنا
    if (_isEditing) {
      bloc.add(BranchesUpdateRequested(
        id: widget.branch!.id,
        centerId: centerId,
        name: name,
        location: location,
      ));
    } else {
      bloc.add(BranchesAddRequested(
        centerId: centerId,
        name: name,
        location: location,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BranchesBloc, BranchesState>(
      // إغلاق الـ Sheet تلقائيًا عند نجاح العملية
      // (رسالة النجاح تعرضها صفحة القائمة عبر المستمع الخاص بها).
      listenWhen: (previous, current) =>
          current.status == BranchesStatus.operationCompleted,
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
                      _isEditing ? 'تعديل الفرع' : 'إضافة فرع جديد',
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

              if (widget.centers.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spacing12),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Text(
                    'لا توجد مراكز متاحة لاختيارها — أضف مركزًا من شاشة المراكز '
                    'أولًا، أو تحقق من اتصالك بالإنترنت',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing16),
              ],

              // المركز التابع له الفرع (إلزامي)
              AppDropdownField<String>(
                label: '${AppStrings.center} *',
                items: widget.centers
                    .map(
                      (center) => DropdownMenuItem<String>(
                        value: center.id,
                        child: Text(center.name),
                      ),
                    )
                    .toList(),
                value: _selectedCenterId,
                hint: 'اختر المركز',
                enabled: widget.centers.isNotEmpty,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'المركز مطلوب' : null,
                onChanged: (value) => setState(() => _selectedCenterId = value),
              ),
              const SizedBox(height: AppDimensions.spacing16),

              AppTextField(
                label: '${AppStrings.name} *',
                controller: _nameController,
                hintText: 'مثال: فرع الحي الشرقي',
                prefixIcon: Icons.location_city_rounded,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                validator: AppValidators.name,
              ),
              const SizedBox(height: AppDimensions.spacing16),

              AppTextField(
                label: 'الموقع',
                controller: _locationController,
                hintText: 'وصف اختياري للموقع',
                prefixIcon: Icons.place_rounded,
                maxLines: 2,
                maxLength: 500,
                validator: (value) =>
                    AppValidators.description(value, fieldName: 'الموقع'),
              ),
              const SizedBox(height: AppDimensions.spacing24),

              BlocBuilder<BranchesBloc, BranchesState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status,
                builder: (builderContext, state) {
                  final isSubmitting =
                      state.status == BranchesStatus.submitting;
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
