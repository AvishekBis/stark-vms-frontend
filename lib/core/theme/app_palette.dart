import 'package:flutter/material.dart';

/// Stark Group brand palette — "navy and gold" (ADR 0025). The ONLY place where colour values
/// live; widgets read colours through `Theme.of(context)`, [StatusColors] or [AppDecorations].
///
/// Gold is an accent, never a text colour on a light surface: `gold` on `surface` is about 2.4:1,
/// far below the 4.5:1 that body text needs. Use it for rules, borders, icon glyphs on dark fills
/// and card edges; use [goldInk] when gold-tinted text must stay readable.
abstract final class AppPalette {
  /// Primary brand colour and the base of every dark gradient.
  static const Color navy = Color(0xFF0E2A4A);

  /// Lighter end of the header gradient.
  static const Color navyLight = Color(0xFF1C4C7C);

  /// Deepest navy, used for the far end of gradients and for pressed states.
  static const Color navyDeep = Color(0xFF08192E);

  static const Color blue = Color(0xFF2E75B6);
  static const Color blueTint = Color(0x332E75B6);

  /// Champagne gold: rules, card edges, selected indicators, icon glyphs on navy.
  static const Color gold = Color(0xFFC8A449);

  /// Pale gold for large washes and hairlines on light surfaces.
  static const Color goldSoft = Color(0xFFE7D7A8);

  /// A 12 % gold veil, for hover fills and the tint behind a gold icon.
  static const Color goldTint = Color(0x1FC8A449);

  /// Dark gold that passes 4.5:1 on [surface] and on [background], for text and small glyphs.
  static const Color goldInk = Color(0xFF7A5E12);

  static const Color green = Color(0xFF1E7A4B);
  static const Color amber = Color(0xFFB87A00);
  static const Color red = Color(0xFFB3261E);
  static const Color grey = Color(0xFF5B6673);

  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF16202B);

  /// Muted body text; 5.6:1 on [surface].
  static const Color inkMuted = Color(0xFF4A5663);

  /// Warm off-white page background; the cream that makes the navy read as rich rather than flat.
  static const Color background = Color(0xFFFAF8F3);

  static const Color surface = Color(0xFFFFFFFF);

  /// Slightly warm surface for secondary panels and table headers.
  static const Color surfaceMuted = Color(0xFFF4F1EA);

  static const Color outline = Color(0xFFDCD7CC);

  /// Hairline inside cards, lighter than [outline].
  static const Color outlineSoft = Color(0xFFEDE9E1);
}
