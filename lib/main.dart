import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bootstrap.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';

/// شاشة خطأ إقلاع موحّدة تعرض إرشادات الإعداد بالعربية.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Cairo', useMaterial3: true),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.settings_suggest_rounded,
                              color: AppColors.primary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppStrings.appName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'تعذر إكمال تهيئة التطبيق',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runZonedGuarded(() async {
    try {
      await bootstrap();
    } catch (error) {
      // عرض شاشة إرشادية عربية عند فشل التهيئة
      // (مثال: firebase_options.dart غير مولّد بعد).
      final message = error is Error
          ? error.toString().replaceFirst('Unsupported operation: ', '')
          : error.toString();
      runApp(BootstrapErrorApp(message: message));
    }
  }, (error, stack) {
    // سجل الأخطاء غير المعالجة (للمطوّر فقط، دون عرض معلومات حساسة).
    debugPrint('Unhandled error: $error');
  });
}
