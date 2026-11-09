import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/vehicle.dart';
import 'vehicle_providers.dart';
import 'widgets/delete_vehicle_flow.dart';
import 'widgets/vehicle_status_badge.dart';

/// Vehicle overview with all fields and audit data (FR-V01, FR-X01).
/// v2.0 adds tabs for documents, maintenance and driver history here.
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final int vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AsyncValueView<Vehicle>(
        value: ref.watch(vehicleDetailProvider(vehicleId)),
        onRetry: () => ref.invalidate(vehicleDetailProvider(vehicleId)),
        loadingMessage: 'Loading vehicle…',
        data: (vehicle) => _VehicleOverview(vehicle: vehicle),
      ),
    );
  }
}

class _VehicleOverview extends ConsumerWidget {
  const _VehicleOverview({required this.vehicle});

  final Vehicle vehicle;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await confirmAndDeleteVehicle(context, ref, vehicle);
    if (deleted && context.mounted) {
      context.go(AppRoutes.vehicles);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final textTheme = Theme.of(context).textTheme;
    final fields = <(String, String)>[
      ('Vehicle number', vehicle.vehicleNumber),
      ('Vehicle type', vehicle.vehicleType.label),
      ('Brand', Formatters.orMissing(vehicle.brand)),
      ('Model', Formatters.orMissing(vehicle.model)),
      ('Manufacture year', Formatters.orMissing(vehicle.manufactureYear)),
      ('Colour', Formatters.orMissing(vehicle.color)),
      ('Fuel type', Formatters.orMissing(vehicle.fuelType?.label)),
      ('Created', Formatters.dateTime(vehicle.createdAt)),
      ('Last updated', Formatters.dateTime(vehicle.updatedAt)),
      ('Created by', Formatters.orMissing(vehicle.createdBy)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.go(AppRoutes.vehicles),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('All vehicles'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            vehicle.vehicleNumber,
                            key: const Key('vehicleDetail.number'),
                            style: textTheme.headlineSmall,
                          ),
                          VehicleStatusBadge(status: vehicle.status),
                        ],
                      ),
                      if (vehicle.brandModel != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(vehicle.brandModel!, style: textTheme.titleMedium),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.xl,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final (label, value) in fields)
                            _DetailField(label: label, value: value),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilledButton.icon(
                            key: const Key('vehicleDetail.edit'),
                            onPressed: () =>
                                context.go(AppRoutes.editVehicle(vehicle.id)),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          if (isAdmin)
                            OutlinedButton.icon(
                              key: const Key('vehicleDetail.delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .error,
                              ),
                              onPressed: () => _delete(context, ref),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: AppSpacing.detailFieldWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
