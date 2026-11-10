import 'package:flutter/material.dart';

import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/status_colors.dart';

/// A coloured pill that always shows text next to the colour, so it stays
/// readable for colour-blind users and in print (guideline 14.2).
///
/// The fill is the [StatusColors] tone and nothing else: no gradient, no
/// second shade, so a test can still read the tone off the decoration.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colors.foreground(tone),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background(tone),
          borderRadius: BorderRadius.circular(AppDecorations.radiusSmall),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xs,
            vertical: AppSpacing.xs + 1,
          ),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}
