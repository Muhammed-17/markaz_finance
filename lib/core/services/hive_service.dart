import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart' as c;
import '../errors/exceptions.dart';
import 'hive_encryption_service.dart';

/// غلاف مركزي لخدمة Hive — التخزين المحلي المؤقت فقط.
///
/// قواعد صارمة:
/// 1) Hive ليس مصدرًا موثوقًا للأرصدة المالية أو الصلاحيات إطلاقًا.
/// 2) لا تُخزَّن كلمات المرور أو الرموز الحساسة هنا.
/// 3) بيانات المستخدم الحساسة تُمسح عند تسجيل الخروج.
/// 4) [pendingOperationsBox] مشفَّر بـ AES-256 لحماية البيانات المالية الحساسة.
class HiveService {
  HiveService({required HiveEncryptionService encryptionService})
      : _encryption = encryptionService;

  static const String _cachedAtKey = '__cachedAt';

  final HiveEncryptionService _encryption;
  bool _initialized = false;
  final Map<String, Box<dynamic>> _openBoxes = {};

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _initialized = true;
  }

  Box<dynamic> _box(String name) {
    if (!Hive.isBoxOpen(name)) {
      throw StateError('Box $name not opened. Call openDefaultBoxes first.');
    }
    return Hive.box<dynamic>(name);
  }

  /// فتح الصناديق المطلوبة مسبقًا (يُستدعى مرة عند الإقلاع).
  ///
  /// [pendingOperationsBox] يُفتح بمشفّر AES-256 لحماية البيانات المالية الحساسة.
  Future<void> openDefaultBoxes() async {
    await _ensureBox(c.AppCollections.settingsBox);
    await _ensureBox(c.AppCollections.draftsBox);
    await _ensureBox(c.AppCollections.cacheCentersBox);
    await _ensureBox(c.AppCollections.cacheBranchesBox);
    await _ensureBox(c.AppCollections.cacheEnvelopesBox);
    await _ensureBox(c.AppCollections.cacheUsersBox);
    await _ensureBox(c.AppCollections.cacheCategoriesBox);
    // الطابور يحتوي على مبالغ ومعرفات مالية — يُفتح بمشفّر AES-256
    final cipher = await _encryption.getOrCreateCipher();
    await _openEncryptedPendingBox(cipher);
  }

  /// يفتح صندوق الطابور المشفَّر ويهاجر إليه محتوى الصندوق القديم (غير المشفَّر).
  ///
  /// - اسم صندوق جديد منفصل: لا نفتح ملفًا غير مشفَّر بمفتاح (Hive كان سيعتبره
  ///   تالفًا ويتجاهل محتواه بصمت).
  /// - الهجرة آمنة ضد الانقطاع: يُكتب كل شيء في الجديد أولًا ثم يُحذف القديم،
  ///   وإن توقفت العملية في المنتصف تُعاد من جديد عند الإقلاع التالي (put بنفس id).
  /// - إن تعذّر فتح المشفَّر (مفتاح مفقود/ملف تالف) يُعاد إنشاؤه فارغًا بدل أن
  ///   يتعطل التطبيق عند الإقلاع.
  Future<void> _openEncryptedPendingBox(HiveCipher cipher) async {
    final name = c.AppCollections.pendingOperationsBox;
    final legacy = c.AppCollections.legacyPendingOperationsBox;

    Box<dynamic> box;
    try {
      box = await _ensureBox(name, encryptionCipher: cipher);
    } catch (e) {
      debugPrint('HiveService: encrypted pending box unreadable, recreating: $e');
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
      box = await _ensureBox(name, encryptionCipher: cipher);
    }

    try {
      if (await Hive.boxExists(legacy)) {
        final old = await Hive.openBox<dynamic>(legacy);
        for (final key in old.keys) {
          final value = old.get(key);
          if (value != null) await box.put(key, value);
        }
        await old.close();
        await Hive.deleteBoxFromDisk(legacy);
      }
    } catch (e) {
      // فشل الهجرة لا يوقف الإقلاع؛ تُعاد المحاولة في التشغيل التالي.
      debugPrint('HiveService: legacy pending box migration failed: $e');
    }
  }

  Future<Box<dynamic>> _ensureBox(
    String name, {
    HiveCipher? encryptionCipher,
  }) async {
    final box = await Hive.openBox<dynamic>(
      name,
      encryptionCipher: encryptionCipher,
    );
    _openBoxes[name] = box;
    return box;
  }

  // ================= إعدادات الواجهة =================

  Future<void> saveSetting(String key, Object value) async {
    final box = await _ensureBox(c.AppCollections.settingsBox);
    await box.put(key, value);
  }

  T? getSetting<T>(String key) {
    try {
      final box = _box(c.AppCollections.settingsBox);
      return box.get(key) as T?;
    } catch (e) {
      debugPrint('HiveService.getSetting error: $e');
      return null;
    }
  }

  // ================= التخزين المؤقت للقوائم المرجعية =================

  /// تخزين قائمة خرائط (نماذج مبسطة) مع طابع زمني للتخزين.
  Future<void> cacheList(String boxName, List<Map<String, dynamic>> items) async {
    try {
      final box = await _ensureBox(boxName);
      await box.put('items', items);
      await box.put(_cachedAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('HiveService.cacheList($boxName) error: $e');
    }
  }

  /// قراءة قائمة مخزنة مؤقتًا، مع طابع زمني. ترجع null إن لم توجد.
  ({List<Map<String, dynamic>> items, DateTime? cachedAt})?
      getCachedList(String boxName) {
    try {
      final box = _box(boxName);
      final raw = box.get('items');
      final cachedAtMs = box.get(_cachedAtKey) as int?;
      if (raw == null) return null;
      final items = (raw as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
      return (
        items: items,
        cachedAt: cachedAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(cachedAtMs),
      );
    } catch (e) {
      debugPrint('HiveService.getCachedList($boxName) error: $e');
      return null;
    }
  }

  /// مسح صندوق تخزين مؤقت.
  Future<void> clearBox(String boxName) async {
    try {
      final box = await _ensureBox(boxName);
      await box.clear();
    } catch (e) {
      throw CacheException('تعذر مسح البيانات المؤقتة ($boxName)',
          technicalDetails: e.toString());
    }
  }

  // ================= مسودات النماذج غير المرسلة =================

  /// حفظ مسودة حركة/نموذج قبل إرسالها (حماية من الفقد عند انقطاع الاتصال).
  Future<void> saveDraft(String draftId, Map<String, dynamic> data) async {
    try {
      final box = await _ensureBox(c.AppCollections.draftsBox);
      await box.put(draftId, data);
    } catch (e) {
      debugPrint('HiveService.saveDraft error: $e');
    }
  }

  Map<String, dynamic>? getDraft(String draftId) {
    try {
      final box = _box(c.AppCollections.draftsBox);
      final raw = box.get(draftId);
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    } catch (e) {
      debugPrint('HiveService.getDraft error: $e');
      return null;
    }
  }

  Future<void> deleteDraft(String draftId) async {
    try {
      final box = await _ensureBox(c.AppCollections.draftsBox);
      await box.delete(draftId);
    } catch (e) {
      debugPrint('HiveService.deleteDraft error: $e');
    }
  }

  // ================= مسح بيانات الجلسة عند الخروج =================

  /// مسح كل البيانات المحلية الحساسة المرتبطة بالمستخدم عند تسجيل الخروج.
  /// (الإعدادات العامة مثل تفضيلات العرض تبقى)
  Future<void> clearUserData() async {
    await clearBox(c.AppCollections.draftsBox);
    await clearBox(c.AppCollections.cacheCentersBox);
    await clearBox(c.AppCollections.cacheBranchesBox);
    await clearBox(c.AppCollections.cacheEnvelopesBox);
    await clearBox(c.AppCollections.cacheUsersBox);
  }
}
