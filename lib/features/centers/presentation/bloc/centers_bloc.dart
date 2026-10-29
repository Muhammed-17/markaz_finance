import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/center_entity.dart';
import '../../domain/usecases/centers_usecases.dart';

part 'centers_event.dart';
part 'centers_state.dart';

/// Bloc شاشة المراكز — التحميل والبحث المحلي والإضافة والتعديل.
class CentersBloc extends Bloc<CentersEvent, CentersState> {
  CentersBloc({
    required GetCentersCached getCentersCached,
    required AddCenter addCenter,
    required UpdateCenter updateCenter,
  })  : _getCentersCached = getCentersCached,
        _addCenter = addCenter,
        _updateCenter = updateCenter,
        super(const CentersState()) {
    // إعادة التحميل تلغي التحميل الجاري (أحدث طلب يفوز).
    on<CentersLoadRequested>(_onLoadRequested, transformer: restartable());
    on<CentersSearchQueryChanged>(_onSearchQueryChanged);
    on<CentersAddRequested>(_onAddRequested, transformer: droppable());
    on<CentersUpdateRequested>(_onUpdateRequested, transformer: droppable());
  }

  final GetCentersCached _getCentersCached;
  final AddCenter _addCenter;
  final UpdateCenter _updateCenter;

  Future<void> _onLoadRequested(
    CentersLoadRequested event,
    Emitter<CentersState> emit,
  ) async {
    // تحميل جديد: تُمسح الرسائل لتجنب تكرار التنبيهات القديمة.
    emit(CentersState(
      status: state.items.isEmpty
          ? CentersStatus.loading
          : CentersStatus.refreshing,
      items: state.items,
      searchQuery: state.searchQuery,
    ));

    final result = await _getCentersCached();
    result.fold(
      (failure) => emit(CentersState(
        status: CentersStatus.failure,
        items: state.items,
        searchQuery: state.searchQuery,
        failure: failure,
      )),
      (loaded) => emit(CentersState(
        status: loaded.items.isEmpty
            ? CentersStatus.empty
            : CentersStatus.success,
        items: loaded.items,
        searchQuery: state.searchQuery,
        isStale: loaded.isStale,
        cachedAt: loaded.cachedAt,
      )),
    );
  }

  void _onSearchQueryChanged(
    CentersSearchQueryChanged event,
    Emitter<CentersState> emit,
  ) {
    // التصفية تتم محليًا على القائمة المحملة (filteredItems في الحالة).
    emit(state.copyWith(searchQuery: event.query, clearMessage: true));
  }

  Future<void> _onAddRequested(
    CentersAddRequested event,
    Emitter<CentersState> emit,
  ) async {
    final name = event.name.trim();
    if (name.isEmpty) {
      emit(state.copyWith(
        status: CentersStatus.operationFailure,
        clearMessage: true,
        message: 'اسم المركز مطلوب',
      ));
      return;
    }

    emit(state.copyWith(status: CentersStatus.submitting, clearMessage: true));
    final result = await _addCenter(
      name: name,
      description: event.description?.trim(),
    );
    result.fold(
      (failure) => emit(state.copyWith(
        status: CentersStatus.operationFailure,
        message: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: CentersStatus.operationCompleted,
        message: 'تمت إضافة المركز بنجاح',
      )),
    );
    if (result.isRight()) await _reload(emit);
  }

  Future<void> _onUpdateRequested(
    CentersUpdateRequested event,
    Emitter<CentersState> emit,
  ) async {
    final name = event.name.trim();
    if (name.isEmpty) {
      emit(state.copyWith(
        status: CentersStatus.operationFailure,
        clearMessage: true,
        message: 'اسم المركز مطلوب',
      ));
      return;
    }

    emit(state.copyWith(status: CentersStatus.submitting, clearMessage: true));
    final result = await _updateCenter(
      id: event.id,
      name: name,
      description: event.description?.trim(),
    );
    result.fold(
      (failure) => emit(state.copyWith(
        status: CentersStatus.operationFailure,
        message: failure.message,
      )),
      (_) => emit(state.copyWith(
        status: CentersStatus.operationCompleted,
        message: 'تم تعديل المركز بنجاح',
      )),
    );
    if (result.isRight()) await _reload(emit);
  }

  /// إعادة تحميل القائمة بعد نجاح العملية مع الحفاظ على البحث الحالي.
  Future<void> _reload(Emitter<CentersState> emit) async {
    final result = await _getCentersCached();
    result.fold(
      (failure) => emit(CentersState(
        status: CentersStatus.failure,
        items: state.items,
        searchQuery: state.searchQuery,
        failure: failure,
      )),
      (loaded) => emit(CentersState(
        status: loaded.items.isEmpty
            ? CentersStatus.empty
            : CentersStatus.success,
        items: loaded.items,
        searchQuery: state.searchQuery,
        isStale: loaded.isStale,
        cachedAt: loaded.cachedAt,
      )),
    );
  }
}
