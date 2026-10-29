import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/hive_service.dart';
import '../models/center_model.dart';

/// مصدر بيانات المراكز المحلي (Hive) — قائمة مرجعية للعرض فقط.
///
/// قواعد صارمة:
/// - يُخزَّن في صندوق AppCollections.cacheCentersBox.
/// - لا تُخزَّن أي أرصدة أو بيانات مالية هنا إطلاقًا.
/// - يُمسح الصندوق عند تسجيل الخروج (عبر HiveService.clearUserData).
class CentersLocalDataSource {
  CentersLocalDataSource({required HiveService hiveService})
      : _hive = hiveService;

  final HiveService _hive;

  /// تخزين قائمة المراكز مع طابع زمني للتخزين.
  Future<void> cacheCenters(List<CenterModel> centers) {
    return _hive.cacheList(
      AppCollections.cacheCentersBox,
      centers.map((center) => center.toCachedMap()).toList(),
    );
  }

  /// استرجاع القائمة المخزنة مع طابع الزمن، أو null إن لم توجد.
  ({List<CenterModel> items, DateTime? cachedAt})? getCachedCenters() {
    final cached = _hive.getCachedList(AppCollections.cacheCentersBox);
    if (cached == null) return null;
    return (
      items: cached.items.map(CenterModel.fromCachedMap).toList(),
      cachedAt: cached.cachedAt,
    );
  }
}
