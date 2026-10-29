import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/branch_entity.dart';
import '../../domain/usecases/branches_usecases.dart';

part 'branches_event.dart';
part 'branches_state.dart';

/// Bloc شاشة الفروع — التحميل بفلتر مركز، البحث المحلي، الإضافة والتعديل.
class BranchesBloc extends Bloc<BranchesEvent, BranchesState> {
  BranchesBloc({
    required GetBranchesCached getBranchesCached,
    required AddBranch addBranch,
    required UpdateBranch updateBranch,
  })  : _getBranchesCached = getBranchesCached,
        _addBranch = addBranch,
        _updateBranch = updateBranch,
        super(const BranchesState()) {
    // إعادة التحميل تلغي التحميل الجاري (أحدث طلب يفوز) — مهم عند تغيير الفلتر بسرعة.
    on<BranchesLoadRequested>(_onLoadRequested, transformer: restartable());
    on<BranchesCenterFilterChanged>(_onCenterFilterChanged);
    on<BranchesSearchQueryChanged>(_onSearchQueryChanged);
    on<BranchesAddRequested>(_onAddRequested, transformer: droppable());
    on<BranchesUpdateRequested>(_onUpdateRequested, transformer: droppable());
  }

  final GetBranchesCached _getBranchesCached;
  final AddBranch _addBranch;
  final UpdateBranch _updateBranch;

  Future<void> _onLoadRequested(
    BranchesLoadRequested event,
    Emitter<BranchesState> emit,
  ) async {
    final centerId = event.centerId ?? state.selectedCenterId;

    // تحميل جديد: تُمسح الرسائل لتجنب تكرار التنبيهات القديمة.
    emit(BranchesState(
      status: state.items.isEmpty
          ? BranchesStatus.loading
          : BranchesStatus.refreshing,
      items: state.items,
      searchQuery: state.searchQuery,
      selectedCenterId: centerId,
    ));

    final result = await _getBranchesCached(centerId: centerId);
    result.fold(
      (failure) => emit(BranchesState(
        status: BranchesStatus.failure,
        items: state.items,
        searchQuery: state.searchQuery,
        selectedCenterId: centerId,
        failure: failure,
      )),
      (loaded) => emit(BranchesState(
        status: loaded.items.isEmpty
            ? BranchesStatus.empty
            : BranchesStatus.success,
        items: loaded.items,
        searchQuery: state.searchQuery,
        selectedCenterId: centerId,
        isStale: loaded.isStale,
        cachedAt: loaded.cachedAt,
      )),
    );
  }

  void _onCenterFilterChanged(
    BranchesCenterFilterChanged event,
    Emitter<BranchesState> emit,
  ) {
    emit(state.copyWith(
      selectedCenterId: event.centerId,
      // null يعني "الكل" — يجب المسح الصريح لأن copyWith يحتفظ بالقيمة القديمة.
      clearSelectedCenter: event.centerId == null,
      clearMessage: true,
    ));
    add(const BranchesLoadRequested());
  }

  void _onSearchQueryChanged(
    BranchesSearchQueryChanged event,
    Emitter<BranchesState> emit,
  ) {
    // التصفية تتم محليًا على القائمة المحملة (filteredItems في الحالة).
    emit(state.copyWith(searchQuery: event.query, clearMessage: true));
  }

  Future<void> _onAddRequested(
    BranchesAddRequested event,
    Emitter<BranchesState> emit,
  ) async {
    final name = event.name.trim();
    final centerId = event.centerId.trim();
    if (centerId.isEmpty) {
      emit(state.copyWith(
        status: BranchesStatus.operationFailure,
        clearMessage: true,
        message: 'المركز مطلوب — اختر المركز التابع له الفرع',
      ));
      return;
    }
    if (name.isEmpty) {
      emit(state.copyWith(
        status: BranchesStatus.operationFailure,
        clearMessage: true,
        message: 'اسم الفرع مطلوب',
      ));
      return;
    }

    emit(state.copyWith(status: BranchesStatus.submitting, clearMessage: true));
    final result = await _addBranch(
      centerId: centerId,
      name: name,
      location: event.location?.trim(),
    );
    result.fold(
      (failure) => emit(state.copyWith(
        status: BranchesStatus.operationFailure,
        message: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: BranchesStatus.operationCompleted,
        message: 'تمت إضافة الفرع بنجاح',
      )),
    );
    if (result.isRight()) await _reload(emit);
  }

  Future<void> _onUpdateRequested(
    BranchesUpdateRequested event,
    Emitter<BranchesState> emit,
  ) async {
    final name = event.name.trim();
    final centerId = event.centerId.trim();
    if (centerId.isEmpty) {
      emit(state.copyWith(
        status: BranchesStatus.operationFailure,
        clearMessage: true,
        message: 'المركز مطلوب — اختر المركز التابع له الفرع',
      ));
      return;
    }
    if (name.isEmpty) {
      emit(state.copyWith(
        status: BranchesStatus.operationFailure,
        clearMessage: true,
        message: 'اسم الفرع مطلوب',
      ));
      return;
    }

    emit(state.copyWith(status: BranchesStatus.submitting, clearMessage: true));
    final result = await _updateBranch(
      id: event.id,
      centerId: centerId,
      name: name,
      location: event.location?.trim(),
    );
    result.fold(
      (failure) => emit(state.copyWith(
        status: BranchesStatus.operationFailure,
        message: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: BranchesStatus.operationCompleted,
        message: 'تم تعديل الفرع بنجاح',
      )),
    );
    if (result.isRight()) await _reload(emit);
  }

  /// إعادة تحميل القائمة بعد نجاح العملية مع الحفاظ على الفلاتر الحالية.
  Future<void> _reload(Emitter<BranchesState> emit) async {
    final result =
        await _getBranchesCached(centerId: state.selectedCenterId);
    result.fold(
      (failure) => emit(BranchesState(
        status: BranchesStatus.failure,
        items: state.items,
        searchQuery: state.searchQuery,
        selectedCenterId: state.selectedCenterId,
        failure: failure,
      )),
      (loaded) => emit(BranchesState(
        status: loaded.items.isEmpty
            ? BranchesStatus.empty
            : BranchesStatus.success,
        items: loaded.items,
        searchQuery: state.searchQuery,
        selectedCenterId: state.selectedCenterId,
        isStale: loaded.isStale,
        cachedAt: loaded.cachedAt,
      )),
    );
  }
}
