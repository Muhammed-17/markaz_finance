import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// تهيئة خدمات Firebase مركزيًا: Core + App Check + إعدادات Firestore.
/// يُستدعى مرة واحدة من bootstrap عبر حاوية الاعتماديات.
abstract final class FirebaseService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      // إعادة الرمي برسالة إرشادية واضحة للمطوّر.
      throw StateError(
        'تعذر تهيئة Firebase (${e.code}). تأكد من تنفيذ:\n'
        '1) flutterfire configure لتوليد firebase_options.dart\n'
        '2) إضافة ملفات google-services.json / GoogleService-Info.plist\n'
        'التفاصيل: ${e.message}',
      );
    }

    // App Check: حماية الوصول إلى خدمات Firebase.
    try {
      if (kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          // للتطوير استخدم debug؛ وفي الإنتاج بدّل المفتاح بمفتاح reCAPTCHA v3 الحقيقي.
          webProvider: ReCaptchaV3Provider('debug'),
        );
      } else {
        final android = defaultTargetPlatform == TargetPlatform.android;
        final ios = defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS;
        await FirebaseAppCheck.instance.activate(
          androidProvider:
              kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
        );
        if (!android && !ios && kDebugMode) {
          // منصات سطح المكتب في التطوير: مزود debug فقط.
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
            appleProvider: AppleProvider.debug,
          );
        }
      }
    } catch (e) {
      // فشل App Check لا يجب أن يوقف التطبيق في التطوير.
      debugPrint('AppCheck activation warning: $e');
    }

    // تفعيل التخزين المؤقت لـ Firestore (دعم وضع عدم الاتصال).
    try {
      final db = FirebaseFirestore.instance;
      db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore settings warning: $e');
    }
  }

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
}
