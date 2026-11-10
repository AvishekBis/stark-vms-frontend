import 'package:flutter/material.dart';

import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';

/// A label above its value, used on detail pages.
///
/// The label is small, letter-spaced and muted; the value carries the weight,
/// with a short gold hairline between them so a wall of fields still reads as
/// a set of rows.
class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    this.value,
    this.child,
    this.width = AppSpacing.detailFieldWidth,
  }) : assert(value != null || child != null);

  final String label;
  final String? value;

  /// Shown instead of [value] (e.g. a badge or a link).
  final Widget? child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppPalette.inkMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          AppDecorations.goldRule(
            width: AppSpacing.md,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
          ),
          child ??
              Text(
                value!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppPalette.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
        ],
      ),
    );
  }
}
