import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';

/// Button styles for the actions that sit on a navy page banner (ADR 0025).
///
/// The app-wide button themes assume a light surface — a navy `FilledButton`
/// would vanish into the gradient — so a banner action turns the palette
/// around: a gold fill with navy ink for the primary action, a pale hairline
/// with white ink for the secondary ones. Every combination here stays well
/// above 4.5:1 on the banner gradient.
///
/// A destructive banner action keeps the hairline style rather than red ink:
/// red on navy is unreadable, and the icon, the label and the confirmation
/// dialog already say what the action does.
abstract final class BannerActions {
  /// Touch target of a banner action; [dense] trims it for a 360 px phone,
  /// where several actions wrap onto their own rows and the banner has to
  /// leave the page below it room to breathe.
  static Size _size({required bool dense}) => Size(0, dense ? 38 : 44);

  static EdgeInsets _padding({required bool dense}) => EdgeInsets.symmetric(
    horizontal: dense
        ? AppSpacing.sm + AppSpacing.xs
        : AppSpacing.md + AppSpacing.xs,
  );

  /// Gold fill, navy ink: the one primary action on a banner.
  static ButtonStyle filled({bool dense = false}) {
    return FilledButton.styleFrom(
      backgroundColor: AppPalette.gold,
      foregroundColor: AppPalette.navyDeep,
      minimumSize: _size(dense: dense),
      padding: _padding(dense: dense),
      visualDensity: dense ? VisualDensity.compact : null,
    );
  }

  /// A pale gold hairline with white ink, for a secondary action on a banner.
  static ButtonStyle outlined({bool dense = false}) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppPalette.white,
      side: const BorderSide(color: AppPalette.goldSoft),
      minimumSize: _size(dense: dense),
      padding: _padding(dense: dense),
      visualDensity: dense ? VisualDensity.compact : null,
    );
  }

  /// A quiet text action on a banner, used for the "back to the list" link.
  static ButtonStyle text({bool dense = false}) {
    return TextButton.styleFrom(
      foregroundColor: AppPalette.goldSoft,
      minimumSize: Size(0, dense ? 32 : 40),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      tapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : null,
      visualDensity: dense ? VisualDensity.compact : null,
    );
  }
}
