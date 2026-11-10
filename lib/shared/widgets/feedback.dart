import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/status_colors.dart';

/// Short success / error messages at the bottom of the screen.
abstract final class AppFeedback {
  static void success(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void _show(
    BuildContext context,
    String message, {
    required bool isError,
  }) {
    final statusColors = StatusColors.of(context);
    // A leading glyph in the tone colour, on the navy snackbar from the
    // theme; the message text still carries the meaning.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                size: 20,
                color: isError ? AppPalette.white : AppPalette.gold,
              ),
              const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isError ? statusColors.danger : null,
          showCloseIcon: isError,
        ),
      );
  }
}
