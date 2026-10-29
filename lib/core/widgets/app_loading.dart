import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// مؤشر تحميل موحد.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: AppDimensions.spacing16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// تحميل مضمّن داخل قائمة (لتحميل المزيد).
class AppLoadMoreIndicator extends StatelessWidget {
  const AppLoadMoreIndicator({this.hasMore = true, super.key});

  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.spacing16),
        child: Center(
          child: Text(
            'لا توجد حركات أخرى',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(AppDimensions.spacing16),
      child: Center(
        child: SizedBox(
          width: AppDimensions.iconLarge,
          height: AppDimensions.iconLarge,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// شاشة انتظار كاملة للصفحة.
class AppPageLoader extends StatelessWidget {
  const AppPageLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppLoadingView());
  }
}
