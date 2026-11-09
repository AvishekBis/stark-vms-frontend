import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/labeled_value.dart';
import '../../../shared/widgets/state_views.dart';
import '../../assignments/presentation/assign_driver_dialog.dart';
import '../../assignments/presentation/assignment_history_view.dart';
import '../../assignments/presentation/assignment_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../documents/presentation/documents_tab.dart';
import '../../maintenance/presentation/maintenance_tab.dart';
import '../data/vehicle.dart';
import 'vehicle_detail_tab.dart';
import 'vehicle_providers.dart';
import 'widgets/delete_vehicle_flow.dart';
import 'widgets/vehicle_status_badge.dart';
import 'widgets/vehicle_status_dialog.dart';

/// Vehicle detail with tabs (guideline 14.1): Overview · Documents ·
/// Maintenance · Driver history (FR-V07, FR-D01/02, FR-M01/02, FR-DR02).
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
    this.initialTab = VehicleDetailTab.overview,
  });

  final int vehicleId;

  /// From `/vehicles/:id?tab=documents`.
  final VehicleDetailTab initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AsyncValueView<Vehicle>(
        value: ref.watch(vehicleDetailProvider(vehicleId)),
        onRetry: () => ref.invalidate(vehicleDetailProvider(vehicleId)),
        loadingMessage: 'Loading vehicle…',
        data: (vehicle) => _VehicleTabs(
          key: ValueKey(initialTab),
          vehicle: vehicle,
          initialTab: initialTab,
        ),
      ),
    );
  }
}

class _VehicleTabs extends StatelessWidget {
  const _VehicleTabs({
    super.key,
    required this.vehicle,
    required this.initialTab,
  });

  final Vehicle vehicle;
  final VehicleDetailTab initialTab;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCompact =
        ScreenSize.fromWidth(MediaQuery.sizeOf(context).width) ==
        ScreenSize.compact;
    return DefaultTabController(
      length: VehicleDetailTab.values.length,
      initialIndex: initialTab.index,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => context.go(AppRoutes.vehicles),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('All vehicles'),
                ),
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
                    if (vehicle.brandModel != null)
                      Text(vehicle.brandModel!, style: textTheme.titleMedium),
                  ],
                ),
              ],
            ),
          ),
          TabBar(
            key: const Key('vehicleDetail.tabs'),
            isScrollable: isCompact,
            tabAlignment: isCompact ? TabAlignment.start : null,
            tabs: [
              for (final tab in VehicleDetailTab.values)
                Tab(
                  key: ValueKey('vehicleDetail.tab.${tab.queryValue}'),
                  text: tab.label,
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(vehicle: vehicle),
                DocumentsTab(
                  vehicleId: vehicle.id,
                  vehicleNumber: vehicle.vehicleNumber,
                ),
                MaintenanceTab(vehicleId: vehicle.id),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AssignmentHistoryView.forVehicle(
                    vehicleId: vehicle.id,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.vehicle});

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
    final theme = Theme.of(context);
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xl,
                        runSpacing: AppSpacing.md,
                        children: [
                          LabeledValue(
                            label: 'Status',
                            child: VehicleStatusBadge(status: vehicle.status),
                          ),
                          for (final (label, value) in fields)
                            LabeledValue(label: label, value: value),
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
                              key: const Key('vehicleDetail.changeStatus'),
                              onPressed: () =>
                                  changeVehicleStatus(context, ref, vehicle),
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('Change status'),
                            ),
                          if (isAdmin)
                            OutlinedButton.icon(
                              key: const Key('vehicleDetail.delete'),
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
              const SizedBox(height: AppSpacing.md),
              _CurrentDriverCard(vehicle: vehicle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Current driver with Assign / Change / Unassign (FR-DR02). Only ACTIVE
/// vehicles can receive a driver (BR-05).
class _CurrentDriverCard extends ConsumerWidget {
  const _CurrentDriverCard({required this.vehicle});

  final Vehicle vehicle;

  Future<void> _assign(BuildContext context) async {
    final assigned = await showAssignDriverDialog(context, vehicle: vehicle);
    if (assigned && context.mounted) {
      AppFeedback.success(
        context,
        'Driver assigned to ${vehicle.vehicleNumber}.',
      );
    }
  }

  Future<void> _unassign(BuildContext context, WidgetRef ref) async {
    final driver = vehicle.currentDriver;
    if (driver == null) {
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Unassign driver?',
      message:
          '${driver.fullName} will no longer drive ${vehicle.vehicleNumber}. '
          'The assignment stays in the history.',
      confirmLabel: 'Unassign',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(assignmentActionsProvider).unassign(vehicle.id);
      if (context.mounted) {
        AppFeedback.success(context, '${driver.fullName} unassigned.');
      }
    } on ApiException catch (error) {
      if (context.mounted) {
        AppFeedback.error(context, error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final driver = vehicle.currentDriver;
    final canAssign = vehicle.canReceiveDriver;

    return Card(
      key: const Key('vehicleDetail.driverCard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current driver', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (driver == null)
              Text(
                'No driver assigned.',
                key: const Key('vehicleDetail.noDriver'),
                style: theme.textTheme.bodyLarge,
              )
            else
              ListTile(
                key: const Key('vehicleDetail.currentDriver'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(driver.fullName),
                subtitle: Text(Formatters.orMissing(driver.phone)),
                onTap: () => context.go(AppRoutes.driverDetail(driver.id)),
              ),
            if (!canAssign) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Only active vehicles can be assigned a driver.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  key: const Key('vehicleDetail.assignDriver'),
                  onPressed: canAssign ? () => _assign(context) : null,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(
                    driver == null ? 'Assign driver' : 'Change driver',
                  ),
                ),
                if (driver != null)
                  OutlinedButton.icon(
                    key: const Key('vehicleDetail.unassignDriver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _unassign(context, ref),
                    icon: const Icon(Icons.person_remove_outlined),
                    label: const Text('Unassign'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
