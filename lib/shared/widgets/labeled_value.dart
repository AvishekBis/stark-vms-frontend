import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// A label above its value, used on detail pages.
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
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          child ?? Text(value!, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
