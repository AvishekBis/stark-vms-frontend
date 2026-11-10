import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_providers.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import 'brand.dart';

/// Shown while any request takes longer than 3 s, typically while a
/// sleeping Render instance starts up.
///
/// Navy with a gold spinner and a gold hairline, so it reads as part of the
/// top bar above it rather than a warning.
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
    return DecoratedBox(
      key: const Key('connecting.banner'),
      decoration: const BoxDecoration(
        gradient: AppDecorations.headerGradient,
        border: Border(bottom: BorderSide(color: AppPalette.goldSoft)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: AppSpacing.md,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppPalette.gold,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: Text(
                '$message $hint',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Brand.onNavyMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
