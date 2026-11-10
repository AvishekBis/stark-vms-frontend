import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/page_response.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/banner_actions.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/data_table_frame.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/row_actions.dart';
import '../../../shared/widgets/sort_menu.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/driver.dart';
import '../data/driver_query.dart';
import 'driver_providers.dart';
import 'widgets/driver_widgets.dart';

/// Drivers list (FR-DR01): debounced server search, status filter,
/// sortable columns, pagination, licence expiry badges, current vehicle.
class DriversListScreen extends ConsumerStatefulWidget {
  const DriversListScreen({super.key});

  @override
  ConsumerState<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends ConsumerState<DriversListScreen> {
  late final TextEditingController _searchController;
  final Debouncer _searchDebouncer = Debouncer(delay: AppConfig.searchDebounce);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(driverQueryProvider).search,
    );
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebouncer.run(
      () => ref.read(driverQueryProvider.notifier).setSearch(value),
    );
  }

  void _onSearchSubmitted(String value) {
    _searchDebouncer.cancel();
    ref.read(driverQueryProvider.notifier).setSearch(value);
  }

  void _clearSearch() {
    _searchDebouncer.cancel();
    _searchController.clear();
    ref.read(driverQueryProvider.notifier).setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final listValue = ref.watch(driverListProvider);
    final query = ref.watch(driverQueryProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final screenSize = ScreenSize.fromWidth(MediaQuery.sizeOf(context).width);
    final isCompact = screenSize == ScreenSize.compact;

    return Scaffold(
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              key: const Key('drivers.addFab'),
              onPressed: () => context.go(AppRoutes.newDriver),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Add driver'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Drivers',
              // The one-line subtitle would wrap to four lines on a 360 px
              // phone and push the first row off the screen.
              subtitle: isCompact
                  ? null
                  : 'The people behind the wheel, with their licences.',
              dense: isCompact,
              icon: Icons.badge_outlined,
              actions: [
                if (!isCompact)
                  FilledButton.icon(
                    key: const Key('drivers.add'),
                    style: BannerActions.filled(),
                    onPressed: () => context.go(AppRoutes.newDriver),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Add driver'),
                  ),
              ],
            ),
            SizedBox(height: isCompact ? AppSpacing.sm : AppSpacing.md),
            // Search and filters share one toolbar card, so the page reads as
            // a banner, a toolbar and then the results. A phone drops the
            // card: the vertical room belongs to the rows.
            ListToolbar(
              isCompact: isCompact,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: AppSpacing.searchMinWidth,
                      maxWidth: AppSpacing.searchMaxWidth,
                    ),
                    child: _SearchField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onSubmitted: _onSearchSubmitted,
                      onClear: _clearSearch,
                    ),
                  ),
                  _StatusFilter(status: query.status),
                  SortMenu<DriverSortField>(
                    key: const Key('drivers.sortMenu'),
                    values: DriverSortField.values,
                    label: (field) => field.label,
                    field: query.sortField,
                    direction: query.sortDirection,
                    onSelected: ref.read(driverQueryProvider.notifier).setSort,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSpacing.xs,
              child: listValue.isLoading && listValue.hasValue
                  ? const LinearProgressIndicator()
                  : null,
            ),
            Expanded(
              child: AsyncValueView<PageResponse<Driver>>(
                value: listValue,
                onRetry: () => ref.invalidate(driverListProvider),
                isEmpty: (page) => page.totalElements == 0 && page.isEmpty,
                empty: query.search.isNotEmpty || query.status != null
                    ? EmptyView(
                        icon: Icons.search_off,
                        title: 'No drivers match the search or filter',
                        action: OutlinedButton(
                          onPressed: () {
                            _clearSearch();
                            ref
                                .read(driverQueryProvider.notifier)
                                .setStatus(null);
                          },
                          child: const Text('Clear search and filter'),
                        ),
                      )
                    : EmptyView(
                        icon: Icons.badge_outlined,
                        title: 'No drivers yet',
                        message: 'Add the first driver of the fleet.',
                        action: FilledButton.icon(
                          onPressed: () => context.go(AppRoutes.newDriver),
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('Add driver'),
                        ),
                      ),
                data: (page) => _DriverResults(
                  page: page,
                  query: query,
                  screenSize: screenSize,
                  isAdmin: isAdmin,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('drivers.search'),
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search name, phone or licence',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
    );
  }
}

class _StatusFilter extends ConsumerWidget {
  const _StatusFilter({required this.status});

  final DriverStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilterMenu<DriverStatus>(
      key: const Key('drivers.statusFilter'),
      label: 'Status',
      options: DriverStatus.values,
      optionLabel: (option) => option.label,
      selected: status,
      onChanged: ref.read(driverQueryProvider.notifier).setStatus,
    );
  }
}

class _DriverResults extends ConsumerWidget {
  const _DriverResults({
    required this.page,
    required this.query,
    required this.screenSize,
    required this.isAdmin,
  });

  final PageResponse<Driver> page;
  final DriverQuery query;
  final ScreenSize screenSize;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(driverQueryProvider.notifier);
    void open(Driver driver) => context.go(AppRoutes.driverDetail(driver.id));
    void edit(Driver driver) => context.go(AppRoutes.editDriver(driver.id));
    void delete(Driver driver) => confirmAndDeleteDriver(context, ref, driver);

    final Widget results;
    if (page.isEmpty) {
      results = const EmptyView(
        icon: Icons.find_in_page_outlined,
        title: 'No drivers on this page',
        message: 'Go back to the previous page.',
      );
    } else if (screenSize == ScreenSize.compact) {
      results = ListView.separated(
        itemCount: page.content.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => _DriverCard(
          driver: page.content[index],
          isAdmin: isAdmin,
          onOpen: open,
          onEdit: edit,
          onDelete: delete,
        ),
      );
    } else {
      results = _DriverTable(
        drivers: page.content,
        query: query,
        isFull: screenSize == ScreenSize.expanded,
        isAdmin: isAdmin,
        onSort: controller.sortBy,
        onOpen: open,
        onEdit: edit,
        onDelete: delete,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: results),
        PaginationBar(
          page: page.page,
          totalPages: page.totalPages,
          totalElements: page.totalElements,
          pageSize: query.size,
          pageSizeOptions: DriverQuery.pageSizeOptions,
          itemLabel: page.totalElements == 1 ? 'driver' : 'drivers',
          onPageChanged: controller.goToPage,
          onPageSizeChanged: controller.setPageSize,
        ),
        if (screenSize == ScreenSize.compact)
          const SizedBox(height: AppSpacing.xl * 2),
      ],
    );
  }
}

typedef _DriverCallback = void Function(Driver driver);

class _DriverTable extends StatelessWidget {
  const _DriverTable({
    required this.drivers,
    required this.query,
    required this.isFull,
    required this.isAdmin,
    required this.onSort,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Driver> drivers;
  final DriverQuery query;
  final bool isFull;
  final bool isAdmin;
  final ValueChanged<DriverSortField> onSort;
  final _DriverCallback onOpen;
  final _DriverCallback onEdit;
  final _DriverCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final columns = <(String, DriverSortField?)>[
      ('Name', DriverSortField.fullName),
      ('Phone', null),
      if (isFull) ('Licence number', null),
      ('Licence expiry', DriverSortField.licenseExpiry),
      ('Status', null),
      ('Current vehicle', null),
      if (isFull) ('Added', DriverSortField.createdAt),
      ('Actions', null),
    ];
    final sortIndex = columns.indexWhere((c) => c.$2 == query.sortField);

    return DataTableFrame(
      table: DataTable(
        key: const Key('drivers.table'),
        showCheckboxColumn: false,
        // Tighter than the theme's spacing: the avatar in the name
        // cell needs the room, and the row still fits on one screen.
        columnSpacing: AppSpacing.md,
        sortColumnIndex: sortIndex < 0 ? null : sortIndex,
        sortAscending: query.sortDirection == SortDirection.ascending,
        columns: [
          for (final (label, field) in columns)
            DataColumn(
              label: Text(label),
              onSort: field == null ? null : (_, _) => onSort(field),
            ),
        ],
        rows: [
          for (final (index, driver) in drivers.indexed)
            DataRow(
              key: ValueKey('driver.row.${driver.id}'),
              color: DataTableFrame.zebraRow(index),
              onSelectChanged: (_) => onOpen(driver),
              cells: [
                DataCell(
                  Row(
                    children: [
                      InitialsAvatar(name: driver.fullName, size: 30),
                      const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                      Text(driver.fullName),
                    ],
                  ),
                ),
                DataCell(Text(driver.phone)),
                if (isFull) DataCell(Text(driver.licenseNumber)),
                DataCell(
                  Wrap(
                    spacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(Formatters.date(driver.licenseExpiry)),
                      LicenseExpiryBadge(driver: driver),
                    ],
                  ),
                ),
                DataCell(DriverStatusBadge(status: driver.status)),
                DataCell(_CurrentVehicleLink(driver: driver)),
                if (isFull) DataCell(Text(Formatters.date(driver.createdAt))),
                DataCell(
                  RowActions(
                    keyPrefix: 'driver',
                    id: driver.id,
                    isAdmin: isAdmin,
                    onEdit: () => onEdit(driver),
                    onDelete: () => onDelete(driver),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CurrentVehicleLink extends StatelessWidget {
  const _CurrentVehicleLink({required this.driver});

  final Driver driver;

  @override
  Widget build(BuildContext context) {
    final vehicle = driver.currentVehicle;
    if (vehicle == null) {
      return const Text('Not assigned');
    }
    return TextButton.icon(
      key: ValueKey('driver.vehicle.${driver.id}'),
      onPressed: () => context.go(AppRoutes.vehicleDetail(vehicle.id)),
      icon: const Icon(Icons.directions_car_outlined),
      label: Text(vehicle.vehicleNumber),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.isAdmin,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Driver driver;
  final bool isAdmin;
  final _DriverCallback onOpen;
  final _DriverCallback onEdit;
  final _DriverCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final vehicle = driver.currentVehicle;
    // The leading edge picks up the driver's own status tone, and the badges
    // below still spell that status out in words.
    final tone = StatusColors.of(context)
        .background(DriverStatusBadge.toneFor(driver.status));

    return AccentEdgeCard(
      key: ValueKey('driver.card.${driver.id}'),
      accent: tone,
      onTap: () => onOpen(driver),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm + AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.sm + AppSpacing.xs,
        ),
        // The actions sit under the badges rather than beside the name, so a
        // long name keeps the full width of the card on a 360 px phone.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialsAvatar(
              name: driver.fullName,
              tint: tone.withValues(alpha: 0.14),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One line each: a card is a summary, and the detail page
                  // spells the whole value out.
                  Text(
                    driver.fullName,
                    style: textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${driver.phone} · ${vehicle == null ? 'Not assigned' : 'Drives ${vehicle.vehicleNumber}'}',
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            DriverStatusBadge(status: driver.status),
                            LicenseExpiryBadge(driver: driver),
                          ],
                        ),
                      ),
                      RowActions(
                        keyPrefix: 'driver',
                        id: driver.id,
                        isAdmin: isAdmin,
                        onEdit: () => onEdit(driver),
                        onDelete: () => onDelete(driver),
                      ),
                    ],
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
