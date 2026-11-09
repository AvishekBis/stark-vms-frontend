import 'package:flutter/material.dart';

/// Shown when a save is answered 409 `stale-version` (contract 6.2,
/// ADR 0023): someone else changed the record since the form was opened.
///
/// **Reload** refetches the record and refills the form (local edits are
/// discarded); **Cancel** keeps the form as it is.
class StaleVersionDialog extends StatelessWidget {
  const StaleVersionDialog({super.key, required this.message});

  static const String title = 'Changed by someone else';
  static const String discardWarning =
      'Reloading replaces your unsaved changes.';

  /// Told after a reload, so the user knows the edits are gone.
  static const String reloadedMessage =
      'Reloaded the latest version. Your unsaved changes were discarded.';

  /// The server `detail`.
  final String message;

  /// Resolves to `true` when the user chose Reload.
  static Future<bool> show(
    BuildContext context, {
    required String message,
  }) async {
    final reload = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StaleVersionDialog(message: message),
    );
    return reload ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('staleVersion.dialog'),
      icon: const Icon(Icons.sync_problem_outlined),
      title: const Text(title),
      content: Text('$message\n\n$discardWarning'),
      actions: [
        TextButton(
          key: const Key('staleVersion.cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('staleVersion.reload'),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.refresh),
          label: const Text('Reload'),
        ),
      ],
    );
  }
}
