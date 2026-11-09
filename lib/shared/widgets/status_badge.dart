import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/status_colors.dart';

/// A coloured pill that always shows text next to the colour, so it stays
/// readable for colour-blind users and in print (guideline 14.2).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final textStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: colors.foreground(tone), fontWeight: FontWeight.w600);
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background(tone),
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}
