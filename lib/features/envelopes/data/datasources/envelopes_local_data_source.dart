import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/data/models/envelope_model.dart';
import '../../../../core/services/hive_service.dart';

/// مصدر بيانات الأظرف المحلي (Hive) — للعرض المؤقت فقط دون اتصال.
///
/// قواعد صارمة:
/// - ليس مصدرًا موثوقًا للأرصدة المالية أو الحالات إطلاقًا.
/// - يُستخدم للعرض عند غياب الاتصال وتحديثه من كل بث ناجح.
class EnvelopesLocalDataSource {
  EnvelopesLocalDataSource({required HiveService hiveService})
      : _hive = hiveService;

  final HiveService _hive;

  /// الحد الأقصى لاعتبار الكاش حديثًا (بعده يُعلَّم كقديم).
  static const Duration stalenessThreshold = Duration(minutes: 10);

  String get _boxName => AppCollections.cacheEnvelopesBox;

  /// تخزين قائمة الأظرف في الكاش (كتابة عابرة من كل بث ناجح).
  ///
  /// نستبدل Timestamp بـ DateTime قبل التخزين — Hive يدعم DateTime محليًا
  /// بلا TypeAdapters، وEnvelopeModel.fromCachedMap يقرأ DateTime كما هو.
  Future<void> cacheEnvelopes(List<EnvelopeModel> envelopes) async {
    try {
      final items = envelopes.map((m) {
        final map = m.toCachedMap();
        map['createdAt'] = m.createdAt;
        return map;
      }).toList();
      await _hive.cacheList(_boxName, items);
    } catch (e) {
      debugPrint('EnvelopesLocalDataSource.cacheEnvelopes error: $e');
    }
  }

  /// قراءة الأظرف من الكاش مع وقت التخزين وعَلَمة القِدم.
  /// ترجع قائمة فارغة وcachedAt = null إن لم يوجد كاش.
  Future<({List<EnvelopeModel> envelopes, DateTime? cachedAt, bool isStale})>
      getCachedEnvelopes() async {
    final cached = _hive.getCachedList(_boxName);
    if (cached == null) {
      return (envelopes: const <EnvelopeModel>[], cachedAt: null, isStale: true);
    }
    final models = cached.items
        .map(EnvelopeModel.fromCachedMap)
        .where((m) => m.id.isNotEmpty)
        .toList();
    final cachedAt = cached.cachedAt;
    final isStale = cachedAt == null ||
        DateTime.now().difference(cachedAt) > stalenessThreshold;
    return (envelopes: models, cachedAt: cachedAt, isStale: isStale);
  }
}
