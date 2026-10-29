import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/di/injection.dart';
import 'app/app.dart';
import 'core/widgets/app_shell.dart' show AppBlocObserver;

/// نقطة تجهيز التطبيق قبل الإقلاع:
/// 1) تهيئة الربط مع Flutter.
/// 2) تهيئة Hive + Firebase + الاعتماديات (داخل configureDependencies).
/// 3) تشغيل التطبيق مع مراقب Bloc لتسجيل الأخطاء.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = AppBlocObserver();

  // Hive + Firebase + كل الاعتماديات.
  // قد يرمي StateError برسالة إرشادية واضحة إذا لم يُعدّ Firebase بعد.
  await configureDependencies();

  runApp(const QuranFinanceApp());
}
