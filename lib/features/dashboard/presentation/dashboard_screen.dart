import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
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
    final textTheme = Theme.of(context).textTheme;

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
            Text(
              user == null ? 'Welcome' : 'Welcome, ${user.fullName}',
              key: const Key('dashboard.welcome'),
              style: textTheme.headlineSmall,
            ),
            if (user != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Signed in as ${user.role.label} · ${user.email}',
                style: textTheme.bodyMedium,
              ),
            ],
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

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.summaryCardWidth,
      height: AppSpacing.summaryCardHeight,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

class _TotalVehiclesCard extends ConsumerWidget {
  const _TotalVehiclesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalVehiclesProvider);
    final theme = Theme.of(context);
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Total vehicles', style: theme.textTheme.titleMedium),
            ],
          ),
          const Spacer(),
          total.when(
            data: (count) => Text(
              Formatters.count(count),
              key: const Key('dashboard.totalVehicles'),
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
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
          Text('Quick action', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add a new vehicle to the fleet.',
            style: theme.textTheme.bodyMedium,
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recently added',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.vehicles),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
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
                    ListTile(
                      key: ValueKey('dashboard.recent.${vehicle.id}'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.directions_car_outlined),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
