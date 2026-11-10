import 'package:flutter/material.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/data/auth_models.dart';

/// "Enabled" (green) / "Disabled" (grey): text and colour, never colour
/// alone (guideline 14.2).
class UserEnabledBadge extends StatelessWidget {
  const UserEnabledBadge({super.key, required this.enabled});

  final bool enabled;

  static String labelFor(bool enabled) => enabled ? 'Enabled' : 'Disabled';

  @override
  Widget build(BuildContext context) {
    return StatusBadge(label: labelFor(enabled), tone: toneFor(enabled));
  }

  static StatusTone toneFor(bool enabled) =>
      enabled ? StatusTone.success : StatusTone.neutral;
}

/// The role of an account as a quiet pill: a gold veil with [AppPalette.goldInk]
/// text, which passes 4.5:1 where the gold accent itself would not.
///
/// A role is not a status, so it deliberately stays off the [StatusColors]
/// tones — those are reserved for enabled / disabled.
class UserRoleChip extends StatelessWidget {
  const UserRoleChip({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.goldTint,
        borderRadius: BorderRadius.circular(AppDecorations.radiusSmall),
        border: Border.all(color: AppPalette.goldSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xs,
          vertical: AppSpacing.xs + 1,
        ),
        child: Text(
          role.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppPalette.goldInk,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
