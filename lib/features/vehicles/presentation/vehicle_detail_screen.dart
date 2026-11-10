import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/brand.dart';
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
import '../../../shared/widgets/banner_actions.dart';
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
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              isCompact ? AppSpacing.sm : AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: _VehicleBanner(vehicle: vehicle, isCompact: isCompact),
          ),
          // The tab strip sits on its own white band, so the gold indicator
          // reads as part of the page furniture rather than floating on cream.
          Container(
            margin: EdgeInsets.fromLTRB(
              AppSpacing.md,
              isCompact ? AppSpacing.sm : AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            decoration: AppDecorations.card(),
            child: TabBar(
              key: const Key('vehicleDetail.tabs'),
              isScrollable: isCompact,
              tabAlignment: isCompact ? TabAlignment.start : null,
              // The card's own hairline border already closes the band.
              dividerHeight: 0,
              tabs: [
                for (final tab in VehicleDetailTab.values)
                  Tab(
                    key: ValueKey('vehicleDetail.tab.${tab.queryValue}'),
                    text: tab.label,
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(vehicle: vehicle, showActions: isCompact),
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

/// The navy banner that opens the screen: the vehicle number in the serif
/// face with a gold rule under it, the status badge, and the record actions.
///
/// It sits above the tab bar, so the number and the actions stay in view on
/// every tab. Built from [AppDecorations.headerBanner] and [Brand] rather
/// than `PageHeader`, because the title here needs a key and a badge beside
/// it; the proportions are deliberately the same.
class _VehicleBanner extends StatelessWidget {
  const _VehicleBanner({required this.vehicle, required this.isCompact});

  final Vehicle vehicle;

  /// A 360 px phone gets the lean banner: no icon plate, tighter padding and
  /// no action row, so the tab below it keeps its room.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          vehicle.vehicleNumber,
          key: const Key('vehicleDetail.number'),
          style: textTheme.headlineSmall?.copyWith(color: Brand.onNavy),
        ),
        AppDecorations.goldRule(
          margin: EdgeInsets.only(top: isCompact ? AppSpacing.sm : 10),
        ),
        SizedBox(
          height: isCompact ? AppSpacing.sm : AppSpacing.sm + AppSpacing.xs,
        ),
        Wrap(
          spacing: AppSpacing.sm + AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            VehicleStatusBadge(status: vehicle.status),
            if (vehicle.brandModel != null)
              Text(
                vehicle.brandModel!,
                style: textTheme.titleMedium?.copyWith(
                  color: Brand.onNavyMuted,
                ),
              ),
          ],
        ),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppDecorations.headerBanner(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          isCompact ? AppSpacing.xs : AppSpacing.sm,
          isCompact ? AppSpacing.md : AppSpacing.lg,
          isCompact ? AppSpacing.md : AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              style: BannerActions.text(dense: isCompact),
              onPressed: () => context.go(AppRoutes.vehicles),
              icon: const Icon(Icons.arrow_back),
              label: const Text('All vehicles'),
            ),
            SizedBox(height: isCompact ? AppSpacing.xs : AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: isCompact ? AppSpacing.sm : AppSpacing.md,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isCompact)
                    titleBlock
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconPlate(
                          icon: Icons.directions_car,
                          tint: Brand.navyPlate,
                          color: AppPalette.gold,
                          size: 44,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Flexible(child: titleBlock),
                      ],
                    ),
                  // A phone keeps the actions on the Overview card instead:
                  // three buttons wrapping inside the banner would eat the
                  // room the tab below it needs.
                  if (!isCompact) _RecordActions(vehicle: vehicle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.vehicle, required this.showActions});

  final Vehicle vehicle;

  /// `true` on a phone, where the record actions live on this card rather
  /// than on the banner.
  final bool showActions;

  @override
  Widget build(BuildContext context) {
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
              DecoratedBox(
                decoration: AppDecorations.card(),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeading(
                        title: 'Vehicle record',
                        icon: Icons.fact_check_outlined,
                        rule: false,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Wrap(
                        spacing: AppSpacing.xl,
                        runSpacing: AppSpacing.lg,
                        children: [
                          LabeledValue(
                            label: 'Status',
                            child: VehicleStatusBadge(status: vehicle.status),
                          ),
                          for (final (label, value) in fields)
                            LabeledValue(label: label, value: value),
                        ],
                      ),
                      if (showActions) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _RecordActions(vehicle: vehicle, onBanner: false),
                      ],
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

/// Edit, Change status and Delete for this vehicle record (FR-V03, FR-V04,
/// FR-V07).
///
/// The same three buttons sit on the navy banner on a tablet or a desktop and
/// on the Overview card on a phone, so [onBanner] only swaps the palette:
/// gold-on-navy up there, the app's own light-surface styles down here, where
/// a red Delete is readable.
class _RecordActions extends ConsumerWidget {
  const _RecordActions({required this.vehicle, this.onBanner = true});

  final Vehicle vehicle;
  final bool onBanner;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final deleted = await confirmAndDeleteVehicle(context, ref, vehicle);
    if (deleted && context.mounted) {
      context.go(AppRoutes.vehicles);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    return Wrap(
      spacing: AppSpacing.sm + AppSpacing.xs,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          key: const Key('vehicleDetail.edit'),
          style: onBanner ? BannerActions.filled() : null,
          onPressed: () => context.go(AppRoutes.editVehicle(vehicle.id)),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        if (isAdmin)
          OutlinedButton.icon(
            key: const Key('vehicleDetail.changeStatus'),
            style: onBanner ? BannerActions.outlined() : null,
            onPressed: () => changeVehicleStatus(context, ref, vehicle),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Change status'),
          ),
        if (isAdmin)
          OutlinedButton.icon(
            key: const Key('vehicleDetail.delete'),
            style: onBanner
                ? BannerActions.outlined()
                : OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
      ],
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

    return Container(
      key: const Key('vehicleDetail.driverCard'),
      clipBehavior: Clip.antiAlias,
      decoration: AppDecorations.card(),
      // Transparent Material so the driver row's ripple and hover land on
      // the card surface rather than behind its white fill.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                title: 'Current driver',
                icon: Icons.person_outline,
                rule: false,
              ),
              const SizedBox(height: AppSpacing.md),
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
                  leading: const IconPlate(icon: Icons.person),
                  title: Text(
                    driver.fullName,
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text(Formatters.orMissing(driver.phone)),
                  trailing: const Icon(Icons.chevron_right),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                  ),
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
      ),
    );
  }
}
