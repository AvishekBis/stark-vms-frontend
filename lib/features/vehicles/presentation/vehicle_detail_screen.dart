import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/banner_actions.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/labeled_value.dart';
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

class _VehicleOverview extends StatelessWidget {
  const _VehicleOverview({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final isCompact =
        ScreenSize.fromWidth(MediaQuery.sizeOf(context).width) ==
        ScreenSize.compact;
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
              _VehicleBanner(vehicle: vehicle, isCompact: isCompact),
              SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
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
                          for (final (label, value) in fields)
                            LabeledValue(label: label, value: value),
                        ],
                      ),
                      // On a phone the actions leave the banner, so it stays
                      // short, and sit under the fields instead.
                      if (isCompact) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _RecordActions(vehicle: vehicle, onBanner: false),
                      ],
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

/// The navy banner that opens the record: "All vehicles", the number in the
/// serif face over the gold rule, the status badge and the brand and model,
/// with Edit / Delete at the end on a tablet or desktop.
class _VehicleBanner extends StatelessWidget {
  const _VehicleBanner({required this.vehicle, required this.isCompact});

  final Vehicle vehicle;

  /// Phone layout: tighter padding, no icon plate, actions below the card.
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

/// Edit and (ADMIN) Delete: banner-styled on the navy banner, theme-styled
/// in the record card on a phone.
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
            key: const Key('vehicleDetail.delete'),
            style: onBanner
                ? BannerActions.outlined()
                : OutlinedButton.styleFrom(
                    foregroundColor: StatusColors.of(context).danger,
                  ),
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
      ],
    );
  }
}
