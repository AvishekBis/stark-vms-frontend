import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../documents/presentation/expiring_documents_screen.dart';
import '../../drivers/presentation/driver_providers.dart';
import '../../drivers/presentation/widgets/driver_widgets.dart';
import '../../vehicles/data/vehicle_enums.dart';
import '../../vehicles/presentation/vehicle_providers.dart';
import '../../vehicles/presentation/widgets/vehicle_status_badge.dart';
import '../data/dashboard_summary.dart';
import 'dashboard_providers.dart';

/// Fleet dashboard (FR-DB01, FR-X02) from one `GET /dashboard/summary`.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final isCompact =
        ScreenSize.fromWidth(MediaQuery.sizeOf(context).width) ==
        ScreenSize.compact;

    Future<void> refresh() async {
      ref.invalidate(dashboardSummaryProvider);
      try {
        await ref.read(dashboardSummaryProvider.future);
      } on Exception {
        // The error state with Retry is shown by the view below.
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // The welcome banner: the navy gradient, the serif greeting and
            // the signed-in line, with Refresh on the banner itself.
            PageHeader(
              key: const Key('dashboard.welcome'),
              icon: Icons.insights_outlined,
              dense: isCompact,
              title: user == null ? 'Welcome' : 'Welcome, ${user.fullName}',
              subtitle: user == null
                  ? null
                  : 'Signed in as ${user.role.label} · ${user.email}',
              actions: [
                IconButton(
                  key: const Key('dashboard.refresh'),
                  tooltip: 'Refresh',
                  onPressed: summary.isLoading ? null : refresh,
                  color: Brand.onNavy,
                  disabledColor: Brand.onNavyMuted,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  key: const Key('dashboard.registerVehicle'),
                  onPressed: () => context.go(AppRoutes.newVehicle),
                  icon: const Icon(Icons.add),
                  label: const Text('Register vehicle'),
                ),
                OutlinedButton.icon(
                  key: const Key('dashboard.addDriver'),
                  onPressed: () => context.go(AppRoutes.newDriver),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add driver'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AsyncValueView<DashboardSummary>(
              value: summary,
              onRetry: () => ref.invalidate(dashboardSummaryProvider),
              loadingMessage: 'Loading fleet summary…',
              data: (data) => _SummaryContent(summary: data),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryContent extends ConsumerWidget {
  const _SummaryContent({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final status = StatusColors.of(context);
    final vehicles = summary.vehicles;
    final documents = summary.documents;
    final maintenance = summary.maintenance;
    final drivers = summary.drivers;

    void openVehicles(VehicleStatus? status) {
      if (status == null) {
        ref.read(vehicleQueryProvider.notifier).clearFilters();
        context.go(AppRoutes.vehicles);
      } else {
        context.go(AppRoutes.vehiclesFiltered(status: status.apiValue));
      }
    }

    void openExpiring() =>
        context.go(AppRoutes.expiringDocumentsWithin(documents.withinDays));

    void openDrivers() {
      ref.read(driverQueryProvider.notifier).clearFilters();
      context.go(AppRoutes.drivers);
    }

    void openLicences() {
      ref.read(driverQueryProvider.notifier).showByLicenceExpiry();
      context.go(AppRoutes.drivers);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Vehicles', icon: Icons.directions_car_outlined),
        _StatGrid(
          cards: [
            _StatCard(
              key: const Key('dashboard.vehicles.total'),
              icon: Icons.directions_car,
              label: 'Total vehicles',
              value: Formatters.count(vehicles.total),
              onTap: () => openVehicles(null),
            ),
            _StatCard(
              key: const Key('dashboard.vehicles.active'),
              icon: Icons.check_circle_outline,
              label: 'Active',
              value: Formatters.count(vehicles.active),
              tone: VehicleStatusBadge.toneFor(VehicleStatus.active),
              onTap: () => openVehicles(VehicleStatus.active),
            ),
            _StatCard(
              key: const Key('dashboard.vehicles.maintenance'),
              icon: Icons.build_outlined,
              label: 'Under maintenance',
              value: Formatters.count(vehicles.maintenance),
              tone: VehicleStatusBadge.toneFor(VehicleStatus.maintenance),
              onTap: () => openVehicles(VehicleStatus.maintenance),
            ),
            _StatCard(
              key: const Key('dashboard.vehicles.inactive'),
              icon: Icons.block,
              label: 'Inactive',
              value: Formatters.count(vehicles.inactive),
              tone: VehicleStatusBadge.toneFor(VehicleStatus.inactive),
              onTap: () => openVehicles(VehicleStatus.inactive),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SectionTitle(
          'Documents, maintenance and drivers',
          icon: Icons.fact_check_outlined,
        ),
        _StatGrid(
          cards: [
            _StatCard(
              key: const Key('dashboard.documents.expired'),
              icon: Icons.event_busy,
              label: 'Documents expired',
              value: Formatters.count(documents.expired),
              tone: StatusTone.danger,
              onTap: openExpiring,
            ),
            _StatCard(
              key: const Key('dashboard.documents.expiringSoon'),
              icon: Icons.schedule,
              label: 'Expiring within ${documents.withinDays} days',
              value: Formatters.count(documents.expiringSoon),
              tone: StatusTone.warning,
              onTap: openExpiring,
            ),
            _StatCard(
              key: const Key('dashboard.maintenance.month'),
              icon: Icons.receipt_long_outlined,
              label: 'Maintenance · ${Formatters.month(maintenance.month)}',
              value: Formatters.money(maintenance.totalCost),
              detail:
                  '${Formatters.count(maintenance.count)} '
                  '${maintenance.count == 1 ? 'record' : 'records'} this month',
            ),
            _StatCard(
              key: const Key('dashboard.drivers'),
              icon: Icons.badge_outlined,
              label: 'Drivers',
              value: Formatters.count(drivers.total),
              detail:
                  '${Formatters.count(drivers.active)} active · '
                  '${Formatters.count(drivers.assigned)} assigned\n'
                  'Licences: ${Formatters.count(drivers.licensesExpired)} expired · '
                  '${Formatters.count(drivers.licensesExpiringSoon)} expiring',
              onTap: openDrivers,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final documentsList = _ListCard(
              key: const Key('dashboard.expiringDocuments'),
              title: 'Expiring documents',
              icon: Icons.event_note_outlined,
              onViewAll: openExpiring,
              isEmpty: summary.expiringDocuments.isEmpty,
              emptyText: 'No document is expired or expiring soon.',
              children: [
                for (final document in summary.expiringDocuments)
                  ExpiringDocumentTile(document: document),
              ],
            );
            final licencesList = _ListCard(
              key: const Key('dashboard.expiringLicenses'),
              title: 'Driver licences expiring',
              icon: Icons.badge_outlined,
              onViewAll: openLicences,
              isEmpty: summary.expiringLicenses.isEmpty,
              emptyText: 'No driver licence is expired or expiring soon.',
              children: [
                for (final driver in summary.expiringLicenses)
                  Card(
                    key: ValueKey('dashboard.license.${driver.id}'),
                    child: ListTile(
                      leading: IconPlate(
                        icon: Icons.person_outline,
                        tint: status.warning.withValues(alpha: 0.12),
                        size: 36,
                      ),
                      title: Text(driver.fullName),
                      subtitle: Text(
                        'Licence ${driver.licenseNumber} · '
                        'expires ${Formatters.date(driver.licenseExpiry)}',
                      ),
                      trailing: LicenseExpiryBadge(driver: driver),
                      onTap: () =>
                          context.go(AppRoutes.driverDetail(driver.id)),
                    ),
                  ),
              ],
            );
            if (constraints.maxWidth > ScreenSize.expandedMinWidth) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: documentsList),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: licencesList),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                documentsList,
                const SizedBox(height: AppSpacing.md),
                licencesList,
              ],
            );
          },
        ),
        if (summary.generatedAt != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Updated ${Formatters.dateTime(summary.generatedAt)}',
            key: const Key('dashboard.generatedAt'),
            style: textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// A serif section title with a gold-tinted icon plate beside it.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SectionHeading(title: text, icon: icon),
    );
  }
}

/// Cards in 1 / 2 / 4 columns depending on the width.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= AppSpacing.statCardMinWidth * 4
            ? 4
            : width >= AppSpacing.statCardMinWidth * 2
            ? 2
            : 1;
        final cardWidth = (width - AppSpacing.md * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

/// One statistic: a card with a coloured leading edge, an icon plate and the
/// figure in the serif display face.
///
/// The [label] always names what the figure counts, so the edge colour is an
/// echo of the status, never the only signal.
///
/// A thin adaptor over brand.dart's [StatPlate]: it turns the optional status
/// [tone] into the accent colour, gives the plate the grid's fixed height, and
/// keys the figure `stat.value`, which the dashboard tests and the integration
/// journey read.
class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.tone,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final StatusTone? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = tone == null
        ? AppPalette.gold
        : StatusColors.of(context).background(tone!);
    return SizedBox(
      height: AppSpacing.statCardHeight,
      child: StatPlate(
        label: label,
        value: value,
        valueKey: const Key('stat.value'),
        icon: icon,
        accent: accent,
        caption: detail,
        onTap: onTap,
      ),
    );
  }
}

/// One of the two dashboard panels: a card with a serif heading, "View all"
/// and either the rows or an ornament above the empty message.
class _ListCard extends StatelessWidget {
  const _ListCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onViewAll,
    required this.isEmpty,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final IconData icon;
  final VoidCallback onViewAll;
  final bool isEmpty;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: AppDecorations.card(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              title: title,
              icon: icon,
              trailing: TextButton(
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  children: [
                    const Ornament(size: 84, icon: Icons.check_circle_outline),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      emptyText,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: child,
                ),
          ],
        ),
      ),
    );
  }
}
