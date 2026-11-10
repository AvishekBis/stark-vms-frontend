import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_spacing.dart';

/// The shared visual language of the "navy and gold" look (ADR 0025): gradients, shadows, gold
/// rules and the ornament behind empty states. Every screen builds its surfaces from here, so a
/// change to the look is one edit, not ninety.
///
/// Nothing in here carries meaning on its own — status colour stays in `StatusColors`, so a card
/// never signals "expired" by its decoration alone.
abstract final class AppDecorations {
  /// Corner radius of cards, banners and dialogs.
  static const double radius = 14;

  /// Corner radius of small chips and badges.
  static const double radiusSmall = 999;

  /// Height of the gold rule under a page title.
  static const double ruleHeight = 3;

  /// Width of the gold rule under a page title.
  static const double ruleWidth = 56;

  /// The dark header gradient: deep navy on the left, lighter navy on the right.
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppPalette.navyDeep, AppPalette.navy, AppPalette.navyLight],
    stops: [0, 0.55, 1],
  );

  /// A barely-there warm wash for the page background behind the content.
  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFDFCF8), AppPalette.background],
  );

  /// The soft lift under a card. Two layers: a wide ambient shadow and a tight contact shadow.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F0E2A4A), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A0E2A4A), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// A stronger lift for dialogs and the login card.
  static const List<BoxShadow> raisedShadow = [
    BoxShadow(color: Color(0x1A0E2A4A), blurRadius: 36, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x0D0E2A4A), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// A plain surface card: white, hairline border, soft shadow.
  static BoxDecoration card({Color? color, List<BoxShadow>? shadow}) {
    return BoxDecoration(
      color: color ?? AppPalette.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppPalette.outlineSoft),
      boxShadow: shadow ?? cardShadow,
    );
  }

  /// A surface card with a coloured strip down its leading edge — the treatment for a card that
  /// leads with a figure or carries a status tone.
  ///
  /// This is a widget, not a [BoxDecoration], on purpose: a BoxDecoration cannot hold a border
  /// radius together with a border whose sides differ in colour (Flutter asserts on every paint),
  /// so the strip is clipped inside the rounded card instead.
  ///
  /// [accent] colours the strip, so a card can pick up its own status tone while the rest of the
  /// decoration stays identical. The label or badge inside still names the state, so the strip is
  /// never the only signal.
  static Widget accentCard({
    required Widget child,
    Color accent = AppPalette.gold,
    double edgeWidth = 4,
    List<BoxShadow>? shadow,
  }) {
    return Container(
      decoration: card(shadow: shadow),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Sizes to the padded child; the strip then stretches to that height.
          Padding(
            padding: EdgeInsets.only(left: edgeWidth),
            child: child,
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: edgeWidth,
            child: ColoredBox(color: accent),
          ),
        ],
      ),
    );
  }

  /// The navy banner that opens a page, with the gradient and a faint gold hairline at the bottom.
  static BoxDecoration headerBanner({BorderRadius? borderRadius}) {
    return BoxDecoration(
      gradient: headerGradient,
      borderRadius: borderRadius ?? BorderRadius.circular(radius),
      border: const Border(
        bottom: BorderSide(color: AppPalette.gold, width: 2),
      ),
      boxShadow: cardShadow,
    );
  }

  /// A round tinted plate behind a leading icon.
  static BoxDecoration iconPlate(Color tint) {
    return BoxDecoration(color: tint, shape: BoxShape.circle);
  }

  /// The short gold rule that sits under a page or section title.
  static Widget goldRule({
    double width = ruleWidth,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      width: width,
      height: ruleHeight,
      margin: margin ?? const EdgeInsets.only(top: AppSpacing.sm),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.gold, AppPalette.goldSoft],
        ),
        borderRadius: BorderRadius.all(Radius.circular(ruleHeight)),
      ),
    );
  }
}
