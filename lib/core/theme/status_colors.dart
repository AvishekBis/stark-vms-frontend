import 'package:flutter/material.dart';

import 'app_palette.dart';

/// The tone of a status badge (guideline 14.2 badge table).
enum StatusTone { success, warning, danger, neutral }

/// Theme extension with the status colours used by badges.
///
/// Read it with `StatusColors.of(context)`.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.neutral,
    required this.onNeutral,
  });

  static const StatusColors stark = StatusColors(
    success: AppPalette.green,
    onSuccess: AppPalette.white,
    warning: AppPalette.amber,
    onWarning: AppPalette.ink,
    danger: AppPalette.red,
    onDanger: AppPalette.white,
    neutral: AppPalette.grey,
    onNeutral: AppPalette.white,
  );

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;
  final Color neutral;
  final Color onNeutral;

  static StatusColors of(BuildContext context) {
    return Theme.of(context).extension<StatusColors>() ?? stark;
  }

  Color background(StatusTone tone) {
    return switch (tone) {
      StatusTone.success => success,
      StatusTone.warning => warning,
      StatusTone.danger => danger,
      StatusTone.neutral => neutral,
    };
  }

  Color foreground(StatusTone tone) {
    return switch (tone) {
      StatusTone.success => onSuccess,
      StatusTone.warning => onWarning,
      StatusTone.danger => onDanger,
      StatusTone.neutral => onNeutral,
    };
  }

  @override
  StatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
    Color? neutral,
    Color? onNeutral,
  }) {
    return StatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      neutral: neutral ?? this.neutral,
      onNeutral: onNeutral ?? this.onNeutral,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) {
      return this;
    }
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onNeutral: Color.lerp(onNeutral, other.onNeutral, t)!,
    );
  }
}
