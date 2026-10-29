/// المصدر المركزي الوحيد لكل المقاسات والمسافات في التطبيق.
/// ممنوع وضع أرقام مسافات أو أنصاف أقطار عشوائية داخل الصفحات.
abstract final class AppDimensions {
  // Spacing
  static const double spacing2 = 2;
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;
  static const double spacing40 = 40;
  static const double spacing48 = 48;

  // Padding
  static const double pagePaddingMobile = 16;
  static const double pagePaddingTablet = 24;
  static const double pagePaddingDesktop = 32;
  static const double cardPadding = 16;
  static const double cardPaddingLarge = 24;
  static const double sectionSpacing = 24;
  static const double itemSpacing = 12;

  // Radius
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusExtraLarge = 24;

  // Controls
  static const double buttonHeight = 48;
  static const double buttonHeightSmall = 40;
  static const double inputHeight = 52;
  static const double iconSmall = 16;
  static const double iconMedium = 24;
  static const double iconLarge = 32;
  static const double appBarHeight = 64;
  static const double chipHeight = 32;
  static const double avatarRadius = 22;

  // Layout
  static const double maxContentWidth = 1440;
  static const double sidebarWidth = 260;
  static const double sidebarCollapsedWidth = 72;
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double cardMinWidth = 280;
  static const double tableRowHeight = 56;
  static const double listTileHeight = 72;
  static const double bottomSheetHandleWidth = 48;
  static const double bottomSheetHandleHeight = 4;
}
