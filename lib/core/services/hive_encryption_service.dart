import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// خدمة إدارة مفتاح تشفير Hive المخزَّن بأمان في flutter_secure_storage.
///
/// يُستخدم مفتاح AES-256 واحد طوال عمر التطبيق على الجهاز، وينشأ
/// تلقائيًا عند الاستخدام الأول ويُحفظ في منطقة التخزين الآمن للجهاز
/// (Keystore على Android، Keychain على iOS/macOS).
///
/// قواعد صارمة:
/// - المفتاح لا يُخزَّن في SharedPreferences أو Hive غير المشفَّر.
/// - المفتاح لا يُنقَل خارج الجهاز إطلاقًا.
/// - يُعاد استخدام نفس المفتاح في كل تشغيل — لا إعادة توليد.
class HiveEncryptionService {
  static const String _secureStorageKey = 'hive_aes_encryption_key_v1';

  final FlutterSecureStorage _secureStorage;

  HiveEncryptionService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// إرجاع [HiveCipher] جاهز للاستخدام مع [Hive.openBox].
  ///
  /// ينشئ المفتاح تلقائيًا عند الاستخدام الأول ويحفظه في flutter_secure_storage.
  Future<HiveCipher> getOrCreateCipher() async {
    final key = await _getOrGenerateKey();
    return HiveAesCipher(key);
  }

  Future<Uint8List> _getOrGenerateKey() async {
    final stored = await _secureStorage.read(key: _secureStorageKey);
    if (stored != null) {
      return Uint8List.fromList(base64Decode(stored));
    }

    // توليد مفتاح AES-256 عشوائي (32 بايت)
    final key = _generateSecureKey(32);
    await _secureStorage.write(
      key: _secureStorageKey,
      value: base64Encode(key),
    );
    return key;
  }

  Uint8List _generateSecureKey(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }
}
