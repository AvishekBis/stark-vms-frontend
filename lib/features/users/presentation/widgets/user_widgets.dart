import 'package:flutter/material.dart';

import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/status_badge.dart';

/// "Enabled" (green) / "Disabled" (grey): text and colour, never colour
/// alone (guideline 14.2).
class UserEnabledBadge extends StatelessWidget {
  const UserEnabledBadge({super.key, required this.enabled});

  final bool enabled;

  static String labelFor(bool enabled) => enabled ? 'Enabled' : 'Disabled';

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: labelFor(enabled),
      tone: enabled ? StatusTone.success : StatusTone.neutral,
    );
  }
}
