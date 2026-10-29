import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/envelope_form_params.dart';
import '../../domain/repositories/envelopes_repository.dart';
import '../../domain/usecases/envelopes_usecases.dart';

part 'envelopes_event.dart';
part 'envelopes_state.dart';

/// نوع آخر عملية على الأظرف (لتمييز رسائل النجاح في الواجهة).
enum EnvelopesOperation { none, create, update, archive, transfer }

/// Bloc قائمة الأظرف المالية.
///
/// القائمة تأتي من بث Firestore المباشر (مقروء)، وكل العمليات المالية
/// تُنفذ عبر العمليات المالية الذرية — لا يعرض أي نجاح إلا بعد تأكيد الخادم.
class EnvelopesBloc extends Bloc<EnvelopesEvent, EnvelopesState> {
  EnvelopesBloc({
    required WatchEnvelopes watchEnvelopes,
    required CreateEnvelope createEnvelope,
    required UpdateEnvelope updateEnvelope,
    required ArchiveEnvelope archiveEnvelope,
    required TransferBetweenEnvelopes transferBetweenEnvelopes,
    required EnvelopesRepository repository,
  })  : _watchEnvelopes = watchEnvelopes,
        _createEnvelope = createEnvelope,
        _updateEnvelope = updateEnvelope,
        _archiveEnvelope = archiveEnvelope,
        _transferBetweenEnvelopes = transferBetweenEnvelopes,
        _repository = repository,
        super(const EnvelopesState()) {
    on<EnvelopesLoadRequested>(_onLoadRequested, transformer: droppable());
    on<EnvelopesSearchQueryChanged>(_onSearchQueryChanged);
    on<EnvelopesCreateRequested>(_onCreateRequested);
    on<EnvelopesUpdateRequested>(_onUpdateRequested);
    on<EnvelopesArchiveRequested>(_onArchiveRequested);
    on<EnvelopesTransferRequested>(_onTransferRequested);
  }

  final WatchEnvelopes _watchEnvelopes;
  final CreateEnvelope _createEnvelope;
  final UpdateEnvelope _updateEnvelope;
  final ArchiveEnvelope _archiveEnvelope;
  final TransferBetweenEnvelopes _transferBetweenEnvelopes;

  /// للقراءة من الكاش المحلي عند بدء التحميل (عرض مؤقت دون اتصال).
  final EnvelopesRepository _repository;

  StreamSubscription<List<EnvelopeEntity>>? _envelopesSubscription;

  Future<void> _onLoadRequested(
    EnvelopesLoadRequested event,
    Emitter<EnvelopesState> emit,
  ) async {
    await _envelopesSubscription?.cancel();
    emit(state.copyWith(
      status: state.items.isEmpty
          ? EnvelopesStatus.loading
          : EnvelopesStatus.refreshing,
    ));

    // عرض الكاش المحلي فورًا إن كانت القائمة فارغة (تحسين تجربة دون اتصال).
    if (state.items.isEmpty) {
      final cachedResult = await _repository.getEnvelopesCached();
      cachedResult.fold(
        (_) {},
        (snapshot) {
          if (snapshot.envelopes.isNotEmpty && state.items.isEmpty) {
            emit(state.copyWith(
              status: EnvelopesStatus.success,
              items: snapshot.envelopes,
            ));
          }
        },
      );
    }

    _envelopesSubscription = _watchEnvelopes().listen(
      (envelopes) => emit(state.copyWith(
        status: EnvelopesStatus.success,
        items: envelopes,
        failure: null,
        clearFailure: true,
      )),
      onError: (Object error) {
        final failure = ErrorHandler.handle(error);
        if (state.items.isEmpty) {
          emit(state.copyWith(
            status: EnvelopesStatus.failure,
            failure: failure,
          ));
        } else {
          // البيانات المعروضة قديمة لكنها متاحة — نُنبّه دون إفراغ القائمة.
          emit(state.copyWith(
            status: EnvelopesStatus.operationFailure,
            failure: failure,
            message: failure.message,
            messageToken: state.messageToken + 1,
            lastOperation: EnvelopesOperation.none,
          ));
        }
      },
    );
  }

  void _onSearchQueryChanged(
    EnvelopesSearchQueryChanged event,
    Emitter<EnvelopesState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  Future<void> _onCreateRequested(
    EnvelopesCreateRequested event,
    Emitter<EnvelopesState> emit,
  ) async {
    emit(state.copyWith(
      status: EnvelopesStatus.submitting,
      lastOperation: EnvelopesOperation.create,
      clearFailure: true,
      clearMessage: true,
    ));
    final result = await _createEnvelope(event.params);
    result.fold(
      (failure) => emit(state.copyWith(
        status: EnvelopesStatus.operationFailure,
        failure: failure,
        message: failure.message,
        messageToken: state.messageToken + 1,
      )),
      (_) => emit(state.copyWith(
        status: EnvelopesStatus.operationCompleted,
        message: 'تم إنشاء الظرف بنجاح',
        messageToken: state.messageToken + 1,
      )),
    );
  }

  Future<void> _onUpdateRequested(
    EnvelopesUpdateRequested event,
    Emitter<EnvelopesState> emit,
  ) async {
    emit(state.copyWith(
      status: EnvelopesStatus.submitting,
      lastOperation: EnvelopesOperation.update,
      clearFailure: true,
      clearMessage: true,
    ));
    final result = await _updateEnvelope(event.params);
    result.fold(
      (failure) => emit(state.copyWith(
        status: EnvelopesStatus.operationFailure,
        failure: failure,
        message: failure.message,
        messageToken: state.messageToken + 1,
      )),
      (_) => emit(state.copyWith(
        status: EnvelopesStatus.operationCompleted,
        message: 'تم تحديث بيانات الظرف بنجاح',
        messageToken: state.messageToken + 1,
      )),
    );
  }

  Future<void> _onArchiveRequested(
    EnvelopesArchiveRequested event,
    Emitter<EnvelopesState> emit,
  ) async {
    emit(state.copyWith(
      status: EnvelopesStatus.submitting,
      lastOperation: EnvelopesOperation.archive,
      clearFailure: true,
      clearMessage: true,
    ));
    final result = await _archiveEnvelope(ArchiveEnvelopeParams(
      envelopeId: event.envelopeId,
      status: event.archive ? AppStatuses.archived : AppStatuses.active,
    ));
    result.fold(
      (failure) => emit(state.copyWith(
        status: EnvelopesStatus.operationFailure,
        failure: failure,
        message: failure.message,
        messageToken: state.messageToken + 1,
      )),
      (_) => emit(state.copyWith(
        status: EnvelopesStatus.operationCompleted,
        message: event.archive ? 'تم أرشفة الظرف بنجاح' : 'تم إعادة تنشيط الظرف بنجاح',
        messageToken: state.messageToken + 1,
      )),
    );
  }

  Future<void> _onTransferRequested(
    EnvelopesTransferRequested event,
    Emitter<EnvelopesState> emit,
  ) async {
    emit(state.copyWith(
      status: EnvelopesStatus.submitting,
      lastOperation: EnvelopesOperation.transfer,
      clearFailure: true,
      clearMessage: true,
    ));
    final result = await _transferBetweenEnvelopes(event.transferParams);
    result.fold(
      (failure) => emit(state.copyWith(
        status: EnvelopesStatus.operationFailure,
        failure: failure,
        message: failure.message,
        messageToken: state.messageToken + 1,
      )),
      (_) => emit(state.copyWith(
        status: EnvelopesStatus.operationCompleted,
        // الرسالة المعتمدة حرفيًا لعملية التحويل الداخلي.
        message:
            'تم التحويل بين الظرفين — لم يتغير إجمالي النقد في الخزنة',
        messageToken: state.messageToken + 1,
      )),
    );
  }

  @override
  Future<void> close() {
    _envelopesSubscription?.cancel();
    return super.close();
  }
}
