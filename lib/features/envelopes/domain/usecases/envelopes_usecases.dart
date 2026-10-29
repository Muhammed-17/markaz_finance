import 'package:dartz/dartz.dart';

import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/domain/entities/envelope_transaction_entity.dart';
import '../../../../core/errors/failures.dart';
import '../entities/envelope_form_params.dart';
import '../entities/envelope_reconciliation_entity.dart';
import '../repositories/envelopes_repository.dart';

/// حالات استخدام ميزة الأظرف المالية.
/// كل العمليات المالية تمر عبر المستودع ثم العمليات المالية الذرية.

/// بث مباشر لقائمة الأظرف.
class WatchEnvelopes {
  const WatchEnvelopes(this._repository);

  final EnvelopesRepository _repository;

  Stream<List<EnvelopeEntity>> call() => _repository.watchEnvelopes();
}

/// جلب سجل حركات ظرف معين.
class GetEnvelopeTransactions {
  const GetEnvelopeTransactions(this._repository);

  final EnvelopesRepository _repository;

  Future<Either<Failure, List<EnvelopeTransactionEntity>>> call(
          String envelopeId) =>
      _repository.getEnvelopeTransactions(envelopeId);
}

/// إنشاء ظرف مالي جديد.
class CreateEnvelope {
  const CreateEnvelope(this._repository);

  final EnvelopesRepository _repository;

  Future<Either<Failure, String>> call(EnvelopeFormParams params) =>
      _repository.createEnvelope(params);
}

/// تعديل بيانات ظرف موجود.
class UpdateEnvelope {
  const UpdateEnvelope(this._repository);

  final EnvelopesRepository _repository;

  Future<Either<Failure, Unit>> call(UpdateEnvelopeParams params) =>
      _repository.updateEnvelope(params);
}

/// أرشفة أو إعادة تنشيط ظرف.
class ArchiveEnvelope {
  const ArchiveEnvelope(this._repository);

  final EnvelopesRepository _repository;

  Future<Either<Failure, Unit>> call(ArchiveEnvelopeParams params) =>
      _repository.archiveEnvelope(params);
}

/// تحويل مبلغ بين ظرفين (دون تغيير إجمالي النقد في الخزنة).
class TransferBetweenEnvelopes {
  const TransferBetweenEnvelopes(this._repository);

  final EnvelopesRepository _repository;

  Future<Either<Failure, Unit>> call(TransferParams params) =>
      _repository.transferBetweenEnvelopes(params);
}

/// فحص ومطابقة أرصدة الأظرف بمجموع الحركات (التسوية الدورية — الخيار ج).
class ReconcileEnvelopes {
  const ReconcileEnvelopes(this._repository);

  final EnvelopesRepository _repository;

  Future<Either<Failure, EnvelopeReconciliationResult>> call() =>
      _repository.reconcileEnvelopes();
}
