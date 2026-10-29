/// مدد الحركات الانتقالية والاهتزازات الموحدة.
abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // الشبكة والعمليات
  static const Duration networkTimeout = Duration(seconds: 45);
  static const Duration snackBarDuration = Duration(seconds: 4);
  static const Duration debounceSearch = Duration(milliseconds: 350);
  static const Duration connectivityDebounce = Duration(milliseconds: 700);
}
