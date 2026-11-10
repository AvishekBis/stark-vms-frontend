import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';

// The reusable pieces of the "navy and gold" look (ADR 0025), so every screen
// opens the same way instead of inventing its own banner. Colours come from
// AppPalette, AppDecorations or StatusColors; nothing here holds a colour
// value of its own.

/// The tones for text and glyphs that sit on a navy fill (the page banner, the
/// top bar). Derived from [AppPalette.white], so there is one source of truth.
abstract final class Brand {
  /// Title text on navy.
  static const Color onNavy = AppPalette.white;

  /// Subtitle and secondary text on navy; still well above 4.5:1.
  static final Color onNavyMuted = AppPalette.white.withValues(alpha: 0.78);

  /// The translucent plate behind an icon on navy.
  static final Color navyPlate = AppPalette.white.withValues(alpha: 0.12);

  /// Hairline between elements on navy.
  static final Color navyHairline = AppPalette.white.withValues(alpha: 0.18);
}

/// A Material icon inside a round tinted plate — the leading treatment for a
/// card, a list row or a section title.
///
/// Use the gold tint (the default) for neutral items, and the status tone's
/// tint where the item carries a tone, so the plate never signals state alone.
class IconPlate extends StatelessWidget {
  const IconPlate({
    super.key,
    required this.icon,
    this.tint,
    this.color,
    this.size = 40,
  });

  final IconData icon;

  /// Fill of the plate; defaults to [AppPalette.goldTint].
  final Color? tint;

  /// Glyph colour; defaults to [AppPalette.navy].
  final Color? color;

  /// Diameter of the plate. The glyph is 55 % of it.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: AppDecorations.iconPlate(tint ?? AppPalette.goldTint),
      child: Icon(icon, size: size * 0.55, color: color ?? AppPalette.navy),
    );
  }
}

/// The navy gradient banner that opens a page: serif [title] on white, a thin
/// gold rule under it, an optional one-line [subtitle] and optional [actions].
///
/// Use it once per screen, as the first child of the body. Title, subtitle and
/// actions wrap onto their own lines on a 360 px phone.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.borderRadius,
    this.dense = false,
  });

  final String title;

  /// One short line under the gold rule.
  final String? subtitle;

  /// Shown on a translucent plate to the left of the title.
  final IconData? icon;

  /// Primary actions, laid out at the end of the banner and wrapping below the
  /// title when the screen is narrow.
  final List<Widget> actions;

  /// Pass [BorderRadius.zero] for a banner that spans the full window width.
  final BorderRadius? borderRadius;

  /// Trims the padding, the icon plate and the title one step. Use it on a
  /// phone, where a 92 px banner would leave a list barely two rows tall.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: (dense ? textTheme.titleLarge : textTheme.headlineSmall)
              ?.copyWith(color: Brand.onNavy),
        ),
        AppDecorations.goldRule(
          margin: EdgeInsets.only(top: dense ? AppSpacing.sm : 10),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Text(
            subtitle!,
            style: textTheme.bodyMedium?.copyWith(color: Brand.onNavyMuted),
          ),
        ],
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppDecorations.headerBanner(borderRadius: borderRadius),
      child: Stack(
        children: [
          const Positioned(
            right: -AppSpacing.lg,
            top: -AppSpacing.lg,
            width: 190,
            height: 190,
            child: IgnorePointer(
              child: CustomPaint(painter: _BannerOrnamentPainter()),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? AppSpacing.md : AppSpacing.lg,
              vertical: dense ? AppSpacing.sm + AppSpacing.xs : AppSpacing.lg,
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              children: [
                if (icon == null)
                  titleBlock
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconPlate(
                        icon: icon!,
                        tint: Brand.navyPlate,
                        color: AppPalette.gold,
                        size: dense ? 34 : 44,
                      ),
                      SizedBox(width: dense ? AppSpacing.sm : AppSpacing.md),
                      Flexible(child: titleBlock),
                    ],
                  ),
                if (actions.isNotEmpty)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm + AppSpacing.xs,
                    runSpacing: AppSpacing.sm,
                    children: actions,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A surface card with a coloured strip down its leading edge — the "this item
/// carries a tone" treatment shared by the driver, user, vehicle and
/// assignment cards, so every list leads with the same shape.
///
/// The strip itself comes from [AppDecorations.accentCard]; this widget only
/// adds the tap ripple, on a transparent [Material] so the ripple lands on the
/// card's own white fill rather than on the Scaffold behind it.
class AccentEdgeCard extends StatelessWidget {
  const AccentEdgeCard({
    super.key,
    required this.accent,
    required this.child,
    this.onTap,
  });

  /// Colour of the leading strip; pass the `StatusColors` tone where the item
  /// has one. The card's text always names that state as well, so the strip is
  /// never the only signal.
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppDecorations.accentCard(
      accent: accent,
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null ? child : InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// The avatar of a person row: up to two initials on a round tinted plate —
/// the leading treatment that makes Drivers and Users read as one family of
/// "people" lists.
///
/// The initials are hidden from screen readers: the name sits right beside
/// them, so reading them twice would only add noise.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.tint,
    this.color,
  });

  final String name;

  /// Diameter of the plate.
  final double size;

  /// Fill of the plate; defaults to the gold veil.
  final Color? tint;

  /// Colour of the initials; defaults to navy.
  final Color? color;

  /// Up to two initials of [name], or `?` when there is no letter at all.
  static String initialsOf(String name) {
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join();
    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: AppDecorations.iconPlate(tint ?? AppPalette.goldTint)
            .copyWith(border: Border.all(color: AppPalette.goldSoft)),
        child: Text(
          InitialsAvatar.initialsOf(name),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color ?? AppPalette.navy,
            letterSpacing: 0.4,
            fontSize: size * 0.34,
          ),
        ),
      ),
    );
  }
}

/// The title of a form or picker dialog: a gold-tinted icon plate, the title
/// and a short gold rule under it.
///
/// Shared by every dialog that asks for input (upload, maintenance, assign,
/// change status, change password), so they open the same way. A dialog that
/// only confirms something uses `AlertDialog.icon` with a centred plate
/// instead, as `ConfirmDialog` does. The title wraps rather than overflows on a
/// 360 px phone.
class DialogTitle extends StatelessWidget {
  const DialogTitle({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconPlate(icon: icon, size: 34),
        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              AppDecorations.goldRule(
                width: AppSpacing.xl,
                margin: const EdgeInsets.only(top: AppSpacing.xs),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The search-and-filters bar under a list's [PageHeader]: a card on a tablet
/// or desktop, bare on a phone, where every spare pixel belongs to the rows.
///
/// Shared by all three list screens so the three pages read the same way:
/// banner, toolbar, results.
class ListToolbar extends StatelessWidget {
  const ListToolbar({super.key, required this.isCompact, required this.child});

  final bool isCompact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return child;
    }
    return DecoratedBox(
      decoration: AppDecorations.card(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

/// A serif section title inside a page, with a gold-tinted icon beside it or a
/// short gold rule under it.
///
/// Use it above a card, a table or a group of fields — not at the top of a
/// screen, where [PageHeader] belongs.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    this.rule = true,
  });

  final String title;

  /// Shown on a gold-tinted plate before the title.
  final IconData? icon;

  /// One short explanatory line under the title.
  final String? subtitle;

  /// An action at the end of the row (a button, a menu).
  final Widget? trailing;

  /// The short gold rule under the title; drop it when the heading already has
  /// an [icon] and the page has many sections.
  final bool rule;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconPlate(icon: icon!, size: 34),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge),
              if (rule)
                AppDecorations.goldRule(width: AppDecorations.ruleWidth),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

/// A figure card: a large serif number in navy over its label, with an icon
/// plate and a coloured leading edge.
///
/// Use it for counts and totals. Pass the `StatusColors` tone as [accent] when
/// the figure carries a status; the [label] always says what the number means,
/// so the colour is never the only signal. A tappable plate shows a chevron
/// next to the figure, so "this opens something" does not rest on hover alone.
///
/// Give it a bounded height (the dashboard grid does) and the label stays at
/// the top while the figure sits at the bottom; unbounded, it shrinks to fit.
class StatPlate extends StatelessWidget {
  const StatPlate({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.caption,
    this.onTap,
    this.valueKey,
  });

  /// What the number counts, e.g. "Vehicles".
  final String label;

  /// The figure itself, already formatted.
  final String value;
  final IconData? icon;

  /// Colour of the leading edge and the icon plate tint; defaults to gold.
  final Color? accent;

  /// An optional second line under the figure.
  final String? caption;
  final VoidCallback? onTap;

  /// A key for the figure's [Text], for a screen whose tests read the number
  /// itself (the dashboard's `stat.value`).
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final edge = accent ?? AppPalette.gold;
    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                IconPlate(
                  icon: icon!,
                  tint: edge.withValues(alpha: 0.14),
                  size: 34,
                ),
              ],
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      key: valueKey,
                      style: textTheme.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      size: AppSpacing.md + AppSpacing.xs,
                      color: AppPalette.inkMuted,
                    ),
                ],
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );

    return AppDecorations.accentCard(
      accent: edge,
      // A transparent Material so the ripple paints on the card's own white
      // fill; without it the ink lands on the Scaffold, under the card.
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// A small abstract navy-and-gold ornament — rings, a dotted arc and a
/// stylised route line — for the middle of an empty, error or loading state.
///
/// Deliberately low contrast: it sits above the message and never competes
/// with it. Nothing animates, so it costs one paint.
class Ornament extends StatelessWidget {
  const Ornament({super.key, this.size = 112, this.icon});

  /// Diameter of the ornament.
  final double size;

  /// An optional Material glyph in the middle of the rings.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _OrnamentPainter()),
          ),
          if (icon != null)
            Icon(
              icon,
              size: size * 0.3,
              color: AppPalette.navy.withValues(alpha: 0.45),
            ),
        ],
      ),
    );
  }
}

/// Rings, a gold arc, a dotted circle of points and an arc suggesting a route.
class _OrnamentPainter extends CustomPainter {
  const _OrnamentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    if (radius <= 0) {
      return;
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppPalette.navy.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius * 0.74, ring);

    final goldArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = AppPalette.gold.withValues(alpha: 0.6);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.92,
      math.pi * 0.62,
      false,
      goldArc,
    );

    final dot = Paint()..color = AppPalette.navy.withValues(alpha: 0.16);
    for (var i = 0; i < 12; i++) {
      final angle = i / 12 * 2 * math.pi;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.48),
        1.6,
        dot,
      );
    }

    final route = Path()
      ..moveTo(center.dx - radius * 0.44, center.dy + radius * 0.3)
      ..quadraticBezierTo(
        center.dx,
        center.dy - radius * 0.46,
        center.dx + radius * 0.44,
        center.dy + radius * 0.3,
      );
    canvas.drawPath(
      route,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = AppPalette.navy.withValues(alpha: 0.16),
    );
  }

  @override
  bool shouldRepaint(_OrnamentPainter oldDelegate) => false;
}

/// Three faint chevrons in the top-right corner of a navy banner.
class _BannerOrnamentPainter extends CustomPainter {
  const _BannerOrnamentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = AppPalette.gold.withValues(alpha: 0.2);
    final center = Offset(size.width * 0.62, size.height * 0.46);
    for (var i = 1; i <= 3; i++) {
      final radius = size.shortestSide * (0.16 * i + 0.1);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.62,
        math.pi * 0.76,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_BannerOrnamentPainter oldDelegate) => false;
}
