import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/labeled_value.dart';
import '../../../shared/widgets/state_views.dart';
import '../../assignments/presentation/assignment_history_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/driver.dart';
import 'driver_providers.dart';
import 'widgets/driver_widgets.dart';

/// Driver info with audit fields and the assignment history (FR-DR01/02).
class DriverDetailScreen extends ConsumerWidget {
  const DriverDetailScreen({super.key, required this.driverId});

  final int driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AsyncValueView<Driver>(
        value: ref.watch(driverDetailProvider(driverId)),
        onRetry: () => ref.invalidate(driverDetailProvider(driverId)),
        loadingMessage: 'Loading driver…',
        data: (driver) => _DriverDetail(driver: driver),
      ),
    );
  }
}

class _DriverDetail extends ConsumerWidget {
  const _DriverDetail({required this.driver});

  final Driver driver;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await confirmAndDeleteDriver(context, ref, driver);
    if (deleted && context.mounted) {
      context.go(AppRoutes.drivers);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final theme = Theme.of(context);
    final vehicle = driver.currentVehicle;

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
                  onPressed: () => context.go(AppRoutes.drivers),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('All drivers'),
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
                            driver.fullName,
                            key: const Key('driverDetail.name'),
                            style: theme.textTheme.headlineSmall,
                          ),
                          DriverStatusBadge(status: driver.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.xl,
                        runSpacing: AppSpacing.md,
                        children: [
                          LabeledValue(label: 'Phone', value: driver.phone),
                          LabeledValue(
                            label: 'Licence number',
                            value: driver.licenseNumber,
                          ),
                          LabeledValue(
                            label: 'Licence expiry',
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  Formatters.date(driver.licenseExpiry),
                                  style: theme.textTheme.bodyLarge,
                                ),
                                LicenseExpiryBadge(driver: driver),
                              ],
                            ),
                          ),
                          LabeledValue(
                            label: 'Current vehicle',
                            child: vehicle == null
                                ? Text(
                                    'Not assigned',
                                    style: theme.textTheme.bodyLarge,
                                  )
                                : InkWell(
                                    key: const Key('driverDetail.vehicle'),
                                    onTap: () => context.go(
                                      AppRoutes.vehicleDetail(vehicle.id),
                                    ),
                                    child: Text(
                                      vehicle.vehicleNumber,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: theme.colorScheme.secondary,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                    ),
                                  ),
                          ),
                          LabeledValue(
                            label: 'Created',
                            value: Formatters.dateTime(driver.createdAt),
                          ),
                          LabeledValue(
                            label: 'Last updated',
                            value: Formatters.dateTime(driver.updatedAt),
                          ),
                          LabeledValue(
                            label: 'Created by',
                            value: Formatters.orMissing(driver.createdBy),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilledButton.icon(
                            key: const Key('driverDetail.edit'),
                            onPressed: () =>
                                context.go(AppRoutes.editDriver(driver.id)),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          if (isAdmin)
                            OutlinedButton.icon(
                              key: const Key('driverDetail.delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
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
              const SizedBox(height: AppSpacing.lg),
              Text('Assignment history', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              AssignmentHistoryView.forDriver(driverId: driver.id),
            ],
          ),
        ),
      ),
    );
  }
}
