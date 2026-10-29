import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/center_ref.dart';
import '../../../../core/domain/entities/envelope_entity.dart';
import '../../../../core/domain/entities/envelope_transaction_entity.dart';
import '../../../../core/errors/failures.dart';
import '../entities/envelope_form_params.dart';
import '../entities/envelope_reconciliation_entity.dart';

/// لقطة الأظرف المخزنة مؤقتًا محليًا (عرض مؤقت فقط — ليس مصدرًا موثوقًا للأرصدة).
class EnvelopesCacheSnapshot extends Equatable {
  const EnvelopesCacheSnapshot({
    required this.envelopes,
    required this.cachedAt,
    required this.isStale,
  });

  final List<EnvelopeEntity> envelopes;

  /// وقت التخزين أو null إن لم يوجد كاش.
  final DateTime? cachedAt;

  /// هل الكاش أقدم من الحد المسموح للعرض كبيانات حديثة؟
  final bool isStale;

  bool get isEmpty => envelopes.isEmpty;

  @override
  List<Object?> get props => [envelopes.length, cachedAt, isStale];
}

/// عقد مستودع الأظرف المالية في طبقة النطاق.
///
/// قواعد صارمة:
/// - القراءة من Firestore مباشرة (استعلام مقروء) أو من الكاش للعرض المؤقت.
/// - كل العمليات المالية عبر معاملة Firestore ذريةs حصرًا — لا كتابة من العميل.
/// - لا يلمس العميل حقول currentBalance بالكتابة — الخادم وحده يحدّثها.
abstract class EnvelopesRepository {
  /// بث مباشر لكل الأظرف (نشطة ومؤرشفة) مرتبة بالاسم.
  /// أخطاء الاستعلام تصل عبر Stream.onError ويحوّلها العارض عبر ErrorHandler.
  Stream<List<EnvelopeEntity>> watchEnvelopes();

  /// قراءة الأظرف من الكاش المحلي مع طابع زمني وعَلَمة قِدم (للعرض دون اتصال).
  Future<Either<Failure, EnvelopesCacheSnapshot>> getEnvelopesCached();

  /// سجل حركات ظرف معين (آخر 200 حركة بالترتيب التنازلي).
  Future<Either<Failure, List<EnvelopeTransactionEntity>>>
      getEnvelopeTransactions(String envelopeId);

  /// مراجع المراكز للنموذج (قراءة مباشرة orderBy name).
  Future<Either<Failure, List<CenterRef>>> getCenters();

  /// إنشاء ظرف — عبر دالة createEnvelope. يرجع معرف الظرف الجديد.
  Future<Either<Failure, String>> createEnvelope(EnvelopeFormParams params);

  /// تعديل بيانات ظرف (الحقول المسموحة فقط) — عبر دالة updateEnvelope.
  Future<Either<Failure, Unit>> updateEnvelope(UpdateEnvelopeParams params);

  /// أرشفة أو إعادة تنشيط ظرف — عبر دالة archiveEnvelope.
  Future<Either<Failure, Unit>> archiveEnvelope(ArchiveEnvelopeParams params);

  /// تحويل مبلغ بين ظرفين — عبر دالة transferBetweenEnvelopes.
  /// لا يغير إجمالي النقد في الخزنة.
  Future<Either<Failure, Unit>> transferBetweenEnvelopes(TransferParams params);

  /// إجراء فحص ومطابقة محاسبية دورية للأرصدة مع مجموع الحركات (الخيار ج).
  Future<Either<Failure, EnvelopeReconciliationResult>> reconcileEnvelopes();
}
