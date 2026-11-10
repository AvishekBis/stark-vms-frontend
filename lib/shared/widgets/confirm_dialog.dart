import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/status_colors.dart';
import 'brand.dart';

/// Confirmation dialog for destructive actions (guideline 14.2).
///
/// The icon plate carries the tone — danger when [destructive], gold
/// otherwise — while the title and the button label still say what will
/// happen, so colour is never the only signal.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  /// Shows the dialog; resolves to `true` only if the user confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = StatusColors.of(context).danger;
    return AlertDialog(
      icon: destructive
          ? IconPlate(
              icon: Icons.delete_outline,
              tint: danger.withValues(alpha: 0.12),
              color: danger,
              size: 48,
            )
          : const IconPlate(icon: Icons.help_outline, size: 48),
      title: Text(title),
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: AppPalette.inkMuted),
      ),
      actions: [
        TextButton(
          key: const Key('confirm.cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          key: const Key('confirm.ok'),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: danger,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
