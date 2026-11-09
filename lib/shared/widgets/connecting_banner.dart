import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/theme/app_spacing.dart';

/// Shown while any request takes longer than 3 s, typically while a
/// sleeping Render instance starts up.
class ConnectingBanner extends ConsumerWidget {
  const ConnectingBanner({super.key});

  static const String message = 'Connecting to server…';
  static const String hint =
      'The server may be waking up. This can take up to a minute.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSlow = ref.watch(
      slowRequestMonitorProvider.select((monitor) => monitor.isSlow),
    );
    if (!isSlow) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Material(
      key: const Key('connecting.banner'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: AppSpacing.md,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: Text(
                '$message $hint',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
