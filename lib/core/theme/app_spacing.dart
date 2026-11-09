/// Spacing scale and layout breakpoints used across the app.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Max width of forms and detail cards on wide screens.
  static const double contentMaxWidth = 960;
  static const double formMaxWidth = 720;

  /// Width of the login card.
  static const double loginMaxWidth = 420;

  /// Width range of the vehicle search field.
  static const double searchMinWidth = 220;
  static const double searchMaxWidth = 360;

  /// Size of a dashboard summary card.
  static const double summaryCardWidth = 300;
  static const double summaryCardHeight = 150;

  /// Width of one label/value pair on a detail page.
  static const double detailFieldWidth = 200;

  /// Width of a filter dropdown in a list header.
  static const double filterWidth = 190;

  /// Max width of dialogs with a form or a list.
  static const double dialogMaxWidth = 560;

  /// Height of the scrollable driver list in the assign dialog.
  static const double dialogListHeight = 320;

  /// Size of a dashboard statistic card.
  static const double statCardMinWidth = 220;
  static const double statCardHeight = 160;
}

/// Responsive breakpoints (guideline 14.2).
enum ScreenSize {
  /// < 600 px: cards.
  compact,

  /// 600–1024 px: compact table.
  medium,

  /// > 1024 px: full table.
  expanded;

  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 1024;

  static ScreenSize fromWidth(double width) {
    if (width < mediumMinWidth) {
      return ScreenSize.compact;
    }
    if (width <= expandedMinWidth) {
      return ScreenSize.medium;
    }
    return ScreenSize.expanded;
  }
}
