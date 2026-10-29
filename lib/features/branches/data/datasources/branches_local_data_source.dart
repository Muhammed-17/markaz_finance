import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/hive_service.dart';
import '../models/branch_model.dart';

/// مصدر بيانات الفروع المحلي (Hive) — قائمة مرجعية للعرض فقط.
///
/// قواعد صارمة:
/// - يُخزَّن في صندوق AppCollections.cacheBranchesBox.
/// - لا تُخزَّن أي أرصدة أو بيانات مالية هنا إطلاقًا.
/// - يُمسح الصندوق عند تسجيل الخروج (عبر HiveService.clearUserData).
class BranchesLocalDataSource {
  BranchesLocalDataSource({required HiveService hiveService})
      : _hive = hiveService;

  final HiveService _hive;

  /// تخزين قائمة الفروع مع طابع زمني للتخزين.
  Future<void> cacheBranches(List<BranchModel> branches) {
    return _hive.cacheList(
      AppCollections.cacheBranchesBox,
      branches.map((branch) => branch.toCachedMap()).toList(),
    );
  }

  /// استرجاع القائمة المخزنة مع طابع الزمن، أو null إن لم توجد.
  ({List<BranchModel> items, DateTime? cachedAt})? getCachedBranches() {
    final cached = _hive.getCachedList(AppCollections.cacheBranchesBox);
    if (cached == null) return null;
    return (
      items: cached.items.map(BranchModel.fromCachedMap).toList(),
      cachedAt: cached.cachedAt,
    );
  }
}
