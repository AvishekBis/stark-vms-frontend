import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/status_colors.dart';
import 'brand.dart';

/// Width of the card the loading / empty / error states sit in, so a long
/// message wraps into a readable column instead of one wide line.
const double _stateMaxWidth = 420;

/// The shared frame of the three state views: a soft card, centred in the
/// space it gets, with an ornament above the message.
class _StateCard extends StatelessWidget {
  const _StateCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _stateMaxWidth),
      child: DecoratedBox(
        decoration: AppDecorations.card(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
    // The card scrolls instead of overflowing: a tab on a 360 x 640 phone can
    // be shorter than the ornament plus its message.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
            minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered spinner with an optional message, on the shared state card.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      children: [
        const SizedBox.square(
          dimension: AppSpacing.xl,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
        AppDecorations.goldRule(
          width: AppSpacing.xl,
          margin: const EdgeInsets.only(top: AppSpacing.lg),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Friendly "nothing here yet" view with an optional action: the [icon] sits
/// inside the navy-and-gold [Ornament] above the title.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StateCard(
      children: [
        Ornament(icon: icon),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.inkMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
      ],
    );
  }
}

/// Error message with a Retry button, led by the danger-toned icon plate.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry, this.title});

  final String message;
  final String? title;
  final VoidCallback? onRetry;

  /// Picks the user-facing message for any error object.
  static String messageFor(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    if (error is String) {
      return error;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = StatusColors.of(context).danger;
    return _StateCard(
      children: [
        IconPlate(
          icon: Icons.error_outline,
          tint: danger.withValues(alpha: 0.12),
          color: danger,
          size: AppSpacing.xl * 1.75,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title ?? 'Could not load data',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppPalette.inkMuted,
          ),
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('error.retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ],
    );
  }
}

/// Renders the four async states: loading, data, empty and error (retry).
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loadingMessage,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final String? loadingMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: false,
      data: (result) {
        final emptyCheck = isEmpty;
        if (empty != null && emptyCheck != null && emptyCheck(result)) {
          return empty!;
        }
        return data(result);
      },
      loading: () => LoadingView(message: loadingMessage),
      error: (error, _) =>
          ErrorView(message: ErrorView.messageFor(error), onRetry: onRetry),
    );
  }
}
