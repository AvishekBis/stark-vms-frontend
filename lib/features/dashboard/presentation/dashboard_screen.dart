import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../vehicles/data/vehicle.dart';
import '../../vehicles/presentation/widgets/vehicle_status_badge.dart';
import 'dashboard_providers.dart';

/// v1.0 dashboard: welcome, total vehicles, recently added, quick action.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isCompact =
        ScreenSize.fromWidth(MediaQuery.sizeOf(context).width) ==
        ScreenSize.compact;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(totalVehiclesProvider)
            ..invalidate(recentVehiclesProvider);
          await ref.read(totalVehiclesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // The welcome banner: the navy gradient, the serif greeting and
            // the signed-in line.
            PageHeader(
              key: const Key('dashboard.welcome'),
              icon: Icons.insights_outlined,
              dense: isCompact,
              title: user == null ? 'Welcome' : 'Welcome, ${user.fullName}',
              subtitle: user == null
                  ? null
                  : 'Signed in as ${user.role.label} · ${user.email}',
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                const _TotalVehiclesCard(),
                _QuickActionCard(
                  onRegister: () => context.go(AppRoutes.newVehicle),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _RecentVehiclesCard(),
          ],
        ),
      ),
    );
  }
}

/// The fixed-size slot of a summary card, with the gold leading edge of the
/// brand's figure cards.
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, this.padded = true});

  final Widget child;

  /// False when [child] is already a [StatPlate], which draws and pads its
  /// own card.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.summaryCardWidth,
      height: AppSpacing.summaryCardHeight,
      child: padded
          ? AppDecorations.accentCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: child,
              ),
            )
          : child,
    );
  }
}

class _TotalVehiclesCard extends ConsumerWidget {
  const _TotalVehiclesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalVehiclesProvider);
    final theme = Theme.of(context);
    // With a figure: the brand's StatPlate. While loading or on an error: the
    // same card shape, with the progress bar or the message where the figure
    // would be.
    if (total case AsyncData(:final value)) {
      return _DashboardCard(
        padded: false,
        child: StatPlate(
          label: 'Total vehicles',
          value: Formatters.count(value),
          valueKey: const Key('dashboard.totalVehicles'),
          icon: Icons.directions_car,
        ),
      );
    }
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total vehicles',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const IconPlate(icon: Icons.directions_car, size: 34),
            ],
          ),
          const Spacer(),
          total.when(
            data: (count) => Text(
              Formatters.count(count),
              key: const Key('dashboard.totalVehicles'),
              style: theme.textTheme.headlineMedium,
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Row(
              children: [
                Expanded(
                  child: Text(
                    ErrorView.messageFor(error),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Retry',
                  onPressed: () => ref.invalidate(totalVehiclesProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Quick action', style: theme.textTheme.titleSmall),
              ),
              const SizedBox(width: AppSpacing.sm),
              const IconPlate(icon: Icons.add_road, size: 34),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // One line: the card has a fixed height, and with the icon plate in
          // the header a second line would push the button out of it.
          Text(
            'Add a new vehicle to the fleet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.inkMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          FilledButton.icon(
            key: const Key('dashboard.registerVehicle'),
            onPressed: onRegister,
            icon: const Icon(Icons.add),
            label: const Text('Register vehicle'),
          ),
        ],
      ),
    );
  }
}

class _RecentVehiclesCard extends ConsumerWidget {
  const _RecentVehiclesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentVehiclesProvider);
    return DecoratedBox(
      decoration: AppDecorations.card(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              title: 'Recently added',
              icon: Icons.history,
              trailing: TextButton(
                onPressed: () => context.go(AppRoutes.vehicles),
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AsyncValueView<List<Vehicle>>(
              value: recent,
              onRetry: () => ref.invalidate(recentVehiclesProvider),
              isEmpty: (vehicles) => vehicles.isEmpty,
              empty: const EmptyView(
                icon: Icons.directions_car_outlined,
                title: 'No vehicles yet',
                message: 'Registered vehicles will appear here.',
              ),
              data: (vehicles) => Column(
                children: [
                  for (final vehicle in vehicles)
                    // The panel is a white card painted by a DecoratedBox, which
                    // would hide the tile's ink: a ListTile paints on the nearest
                    // Material. A transparent Material gives it one of its own.
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        key: ValueKey('dashboard.recent.${vehicle.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: const IconPlate(
                          icon: Icons.directions_car_outlined,
                          size: 36,
                        ),
                        title: Text(vehicle.vehicleNumber),
                        subtitle: Text(
                          [
                            vehicle.vehicleType.label,
                            vehicle.brandModel,
                            'added ${Formatters.date(vehicle.createdAt)}',
                          ].whereType<String>().join(' · '),
                        ),
                        trailing: VehicleStatusBadge(status: vehicle.status),
                        onTap: () =>
                            context.go(AppRoutes.vehicleDetail(vehicle.id)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
