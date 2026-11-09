import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/page_response.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/vehicle.dart';
import '../data/vehicle_query.dart';
import 'vehicle_providers.dart';
import 'widgets/delete_vehicle_flow.dart';
import 'widgets/vehicle_status_badge.dart';

/// Vehicle list (FR-V01) with server-side search, sort and pagination.
class VehicleListScreen extends ConsumerStatefulWidget {
  const VehicleListScreen({super.key});

  @override
  ConsumerState<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends ConsumerState<VehicleListScreen> {
  late final TextEditingController _searchController;
  final Debouncer _searchDebouncer = Debouncer(delay: AppConfig.searchDebounce);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(vehicleQueryProvider).search,
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
      () => ref.read(vehicleQueryProvider.notifier).setSearch(value),
    );
  }

  /// Enter searches at once instead of waiting for the debounce.
  void _onSearchSubmitted(String value) {
    _searchDebouncer.cancel();
    ref.read(vehicleQueryProvider.notifier).setSearch(value);
  }

  void _clearSearch() {
    _searchDebouncer.cancel();
    _searchController.clear();
    ref.read(vehicleQueryProvider.notifier).setSearch('');
  }

  @override
  Widget build(BuildContext context) {
    final listValue = ref.watch(vehicleListProvider);
    final query = ref.watch(vehicleQueryProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final screenSize = ScreenSize.fromWidth(MediaQuery.sizeOf(context).width);
    final isCompact = screenSize == ScreenSize.compact;

    return Scaffold(
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              key: const Key('vehicles.registerFab'),
              onPressed: () => context.go(AppRoutes.newVehicle),
              icon: const Icon(Icons.add),
              label: const Text('Register vehicle'),
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
            _ListHeader(
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
              onSearchSubmitted: _onSearchSubmitted,
              onClearSearch: _clearSearch,
              query: query,
              showRegisterButton: !isCompact,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSpacing.xs,
              child: listValue.isLoading && listValue.hasValue
                  ? const LinearProgressIndicator()
                  : null,
            ),
            Expanded(
              child: AsyncValueView<PageResponse<Vehicle>>(
                value: listValue,
                onRetry: () => ref.invalidate(vehicleListProvider),
                isEmpty: (page) => page.totalElements == 0 && page.isEmpty,
                empty: _EmptyVehicles(
                  search: query.search,
                  onClearSearch: _clearSearch,
                ),
                data: (page) => _VehicleResults(
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

class _ListHeader extends ConsumerWidget {
  const _ListHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.query,
    required this.showRegisterButton,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VehicleQuery query;
  final bool showRegisterButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchField = TextField(
      key: const Key('vehicles.search'),
      controller: searchController,
      onChanged: onSearchChanged,
      onSubmitted: onSearchSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by vehicle number',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: searchController,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
    );

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text('Vehicles', style: Theme.of(context).textTheme.headlineSmall),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppSpacing.searchMinWidth,
                maxWidth: AppSpacing.searchMaxWidth,
              ),
              child: searchField,
            ),
            _SortMenu(query: query),
            if (showRegisterButton)
              FilledButton.icon(
                key: const Key('vehicles.register'),
                onPressed: () => context.go(AppRoutes.newVehicle),
                icon: const Icon(Icons.add),
                label: const Text('Register vehicle'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Sort picker; on narrow screens there are no column headers to tap.
class _SortMenu extends ConsumerWidget {
  const _SortMenu({required this.query});

  final VehicleQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<(VehicleSortField, SortDirection)>(
      key: const Key('vehicles.sortMenu'),
      tooltip: 'Sort',
      onSelected: (choice) =>
          ref.read(vehicleQueryProvider.notifier).setSort(choice.$1, choice.$2),
      itemBuilder: (context) => [
        for (final field in VehicleSortField.values)
          for (final direction in SortDirection.values)
            CheckedPopupMenuItem<(VehicleSortField, SortDirection)>(
              value: (field, direction),
              checked:
                  query.sortField == field && query.sortDirection == direction,
              child: _SortLabel(field: field, direction: direction),
            ),
      ],
      child: Chip(
        avatar: const Icon(Icons.sort),
        label: _SortLabel(
          field: query.sortField,
          direction: query.sortDirection,
        ),
      ),
    );
  }
}

/// "Date added" plus an arrow icon. An icon, not a '↑'/'↓' character: the
/// bundled text font has no arrow glyphs, so Flutter Web drew an empty box
/// until (or unless) a fallback font was downloaded.
class _SortLabel extends StatelessWidget {
  const _SortLabel({required this.field, required this.direction});

  final VehicleSortField field;
  final SortDirection direction;

  @override
  Widget build(BuildContext context) {
    final ascending = direction == SortDirection.ascending;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(field.label),
        const SizedBox(width: AppSpacing.xs),
        Icon(
          ascending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          semanticLabel: ascending ? 'ascending' : 'descending',
        ),
      ],
    );
  }
}

class _EmptyVehicles extends StatelessWidget {
  const _EmptyVehicles({required this.search, required this.onClearSearch});

  final String search;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    if (search.isNotEmpty) {
      return EmptyView(
        icon: Icons.search_off,
        title: 'No vehicles match "$search"',
        message: 'Try a different vehicle number.',
        action: OutlinedButton(
          onPressed: onClearSearch,
          child: const Text('Clear search'),
        ),
      );
    }
    return EmptyView(
      icon: Icons.directions_car_outlined,
      title: 'No vehicles registered yet',
      message: 'Register the first vehicle of the fleet.',
      action: FilledButton.icon(
        onPressed: () => context.go(AppRoutes.newVehicle),
        icon: const Icon(Icons.add),
        label: const Text('Register vehicle'),
      ),
    );
  }
}

class _VehicleResults extends ConsumerWidget {
  const _VehicleResults({
    required this.page,
    required this.query,
    required this.screenSize,
    required this.isAdmin,
  });

  final PageResponse<Vehicle> page;
  final VehicleQuery query;
  final ScreenSize screenSize;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryController = ref.read(vehicleQueryProvider.notifier);
    void open(Vehicle vehicle) =>
        context.go(AppRoutes.vehicleDetail(vehicle.id));
    void edit(Vehicle vehicle) => context.go(AppRoutes.editVehicle(vehicle.id));
    void delete(Vehicle vehicle) =>
        confirmAndDeleteVehicle(context, ref, vehicle);

    final results = page.isEmpty
        ? const EmptyView(
            icon: Icons.find_in_page_outlined,
            title: 'No vehicles on this page',
            message: 'Go back to the previous page.',
          )
        : screenSize == ScreenSize.compact
        ? _VehicleCards(
            vehicles: page.content,
            isAdmin: isAdmin,
            onOpen: open,
            onEdit: edit,
            onDelete: delete,
          )
        : _VehicleTable(
            vehicles: page.content,
            query: query,
            isFull: screenSize == ScreenSize.expanded,
            isAdmin: isAdmin,
            onSort: queryController.sortBy,
            onOpen: open,
            onEdit: edit,
            onDelete: delete,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: results),
        PaginationBar(
          page: page.page,
          totalPages: page.totalPages,
          totalElements: page.totalElements,
          pageSize: query.size,
          pageSizeOptions: VehicleQuery.pageSizeOptions,
          itemLabel: page.totalElements == 1 ? 'vehicle' : 'vehicles',
          onPageChanged: queryController.goToPage,
          onPageSizeChanged: queryController.setPageSize,
        ),
        if (screenSize == ScreenSize.compact)
          const SizedBox(height: AppSpacing.xl * 2),
      ],
    );
  }
}

typedef _VehicleCallback = void Function(Vehicle vehicle);

class _VehicleTable extends StatelessWidget {
  const _VehicleTable({
    required this.vehicles,
    required this.query,
    required this.isFull,
    required this.isAdmin,
    required this.onSort,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Vehicle> vehicles;
  final VehicleQuery query;
  final bool isFull;
  final bool isAdmin;
  final ValueChanged<VehicleSortField> onSort;
  final _VehicleCallback onOpen;
  final _VehicleCallback onEdit;
  final _VehicleCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final columns = <_Column>[
      const _Column(
        'Vehicle number',
        sortField: VehicleSortField.vehicleNumber,
      ),
      const _Column('Type'),
      const _Column('Brand / model'),
      const _Column(
        'Year',
        sortField: VehicleSortField.manufactureYear,
        numeric: true,
      ),
      if (isFull) const _Column('Fuel'),
      const _Column('Status'),
      if (isFull) const _Column('Added', sortField: VehicleSortField.createdAt),
      const _Column('Actions'),
    ];
    final sortIndex = columns.indexWhere(
      (column) => column.sortField == query.sortField,
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: DataTable(
                key: const Key('vehicles.table'),
                showCheckboxColumn: false,
                sortColumnIndex: sortIndex < 0 ? null : sortIndex,
                sortAscending: query.sortDirection == SortDirection.ascending,
                columns: [
                  for (final column in columns)
                    DataColumn(
                      label: Text(column.label),
                      numeric: column.numeric,
                      onSort: column.sortField == null
                          ? null
                          : (_, _) => onSort(column.sortField!),
                    ),
                ],
                rows: [
                  for (final vehicle in vehicles)
                    DataRow(
                      key: ValueKey('vehicle.row.${vehicle.id}'),
                      onSelectChanged: (_) => onOpen(vehicle),
                      cells: [
                        DataCell(Text(vehicle.vehicleNumber)),
                        DataCell(Text(vehicle.vehicleType.label)),
                        DataCell(
                          Text(Formatters.orMissing(vehicle.brandModel)),
                        ),
                        DataCell(
                          Text(Formatters.orMissing(vehicle.manufactureYear)),
                        ),
                        if (isFull)
                          DataCell(
                            Text(Formatters.orMissing(vehicle.fuelType?.label)),
                          ),
                        DataCell(VehicleStatusBadge(status: vehicle.status)),
                        if (isFull)
                          DataCell(Text(Formatters.date(vehicle.createdAt))),
                        DataCell(
                          _RowActions(
                            vehicle: vehicle,
                            isAdmin: isAdmin,
                            onEdit: onEdit,
                            onDelete: onDelete,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Column {
  const _Column(this.label, {this.sortField, this.numeric = false});

  final String label;
  final VehicleSortField? sortField;
  final bool numeric;
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.vehicle,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final bool isAdmin;
  final _VehicleCallback onEdit;
  final _VehicleCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('vehicle.edit.${vehicle.id}'),
          tooltip: 'Edit',
          onPressed: () => onEdit(vehicle),
          icon: const Icon(Icons.edit_outlined),
        ),
        if (isAdmin)
          IconButton(
            key: ValueKey('vehicle.delete.${vehicle.id}'),
            tooltip: 'Delete',
            color: Theme.of(context).colorScheme.error,
            onPressed: () => onDelete(vehicle),
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
  }
}

class _VehicleCards extends StatelessWidget {
  const _VehicleCards({
    required this.vehicles,
    required this.isAdmin,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Vehicle> vehicles;
  final bool isAdmin;
  final _VehicleCallback onOpen;
  final _VehicleCallback onEdit;
  final _VehicleCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView.separated(
      itemCount: vehicles.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        final details = [
          vehicle.vehicleType.label,
          vehicle.brandModel,
          vehicle.manufactureYear?.toString(),
          vehicle.fuelType?.label,
        ].whereType<String>().join(' · ');
        return Card(
          key: ValueKey('vehicle.card.${vehicle.id}'),
          child: InkWell(
            onTap: () => onOpen(vehicle),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                0,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.vehicleNumber,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(details, style: textTheme.bodySmall),
                        const SizedBox(height: AppSpacing.sm),
                        VehicleStatusBadge(status: vehicle.status),
                      ],
                    ),
                  ),
                  _RowActions(
                    vehicle: vehicle,
                    isAdmin: isAdmin,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
