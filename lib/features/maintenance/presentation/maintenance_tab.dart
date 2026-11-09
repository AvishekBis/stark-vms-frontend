import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/data_table_frame.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/row_actions.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/maintenance_record.dart';
import 'maintenance_form_dialog.dart';
import 'maintenance_providers.dart';

/// Maintenance history of one vehicle (FR-M01, FR-M02): newest first,
/// paginated, with the total cost of all records. Cards below 600 px, a
/// compact table up to 1024 px, the full table above (guideline 14.2).
class MaintenanceTab extends ConsumerStatefulWidget {
  const MaintenanceTab({super.key, required this.vehicleId});

  final int vehicleId;

  @override
  ConsumerState<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends ConsumerState<MaintenanceTab> {
  int _page = 0;

  ({int vehicleId, int page}) get _key =>
      (vehicleId: widget.vehicleId, page: _page);

  /// After deleting the last record of a later page, show the page before.
  void _stepBackIfPageEmptied(MaintenanceHistory value) {
    if (value.records.isEmpty && _page > 0 && value.recordCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _page = (value.page.totalPages - 1).clamp(0, _page));
        }
      });
    }
  }

  Future<void> _add() async {
    final saved = await showMaintenanceFormDialog(
      context,
      vehicleId: widget.vehicleId,
    );
    if (saved != null && mounted) {
      setState(() => _page = 0);
      AppFeedback.success(context, 'Maintenance record added.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(maintenanceHistoryProvider(_key));
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final theme = Theme.of(context);
    final summary = history.valueOrNull;
    final screenSize = ScreenSize.fromWidth(MediaQuery.sizeOf(context).width);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary == null
                        ? 'Total cost'
                        : 'Total cost ${Formatters.money(summary.totalCost)}',
                    key: const Key('maintenance.totalCost'),
                    style: theme.textTheme.titleMedium,
                  ),
                  if (summary != null)
                    Text(
                      '${Formatters.count(summary.recordCount)} '
                      '${summary.recordCount == 1 ? 'record' : 'records'} in total',
                      key: const Key('maintenance.recordCount'),
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
              FilledButton.icon(
                key: const Key('maintenance.add'),
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add record'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AsyncValueView<MaintenanceHistory>(
              value: history,
              onRetry: () => ref.invalidate(maintenanceHistoryProvider(_key)),
              loadingMessage: 'Loading maintenance history…',
              isEmpty: (value) =>
                  value.recordCount == 0 && value.records.isEmpty,
              empty: const EmptyView(
                icon: Icons.build_outlined,
                title: 'No maintenance recorded yet',
                message:
                    'Add services, repairs and inspections with their cost.',
              ),
              data: (value) {
                _stepBackIfPageEmptied(value);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: screenSize == ScreenSize.compact
                          ? ListView.separated(
                              itemCount: value.records.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) => _MaintenanceCard(
                                record: value.records[index],
                                isAdmin: isAdmin,
                                vehicleId: widget.vehicleId,
                              ),
                            )
                          : _MaintenanceTable(
                              records: value.records,
                              isAdmin: isAdmin,
                              vehicleId: widget.vehicleId,
                              isFull: screenSize == ScreenSize.expanded,
                            ),
                    ),
                    PaginationBar(
                      page: value.page.page,
                      totalPages: value.page.totalPages,
                      totalElements: value.page.totalElements,
                      pageSize: value.page.size,
                      pageSizeOptions: const [],
                      itemLabel: value.page.totalElements == 1
                          ? 'record'
                          : 'records',
                      onPageChanged: (page) => setState(() => _page = page),
                      onPageSizeChanged: (_) {},
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// FR-X01: "Added … by …", plus "updated …" when the record changed after
/// creation.
String _auditText(MaintenanceRecord record) {
  final created = record.createdAt;
  final updated = record.updatedAt;
  final wasEdited =
      created != null &&
      updated != null &&
      updated.difference(created).inSeconds >= 1;
  return [
    Formatters.audit('Added', at: record.createdAt, by: record.createdBy),
    if (wasEdited) 'updated ${Formatters.dateTime(record.updatedAt)}',
  ].join(' · ');
}

class _MaintenanceTable extends StatelessWidget {
  const _MaintenanceTable({
    required this.records,
    required this.isAdmin,
    required this.vehicleId,
    required this.isFull,
  });

  final List<MaintenanceRecord> records;
  final bool isAdmin;
  final int vehicleId;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return DataTableFrame(
      table: DataTable(
        key: const Key('maintenance.table'),
        columnSpacing: AppSpacing.md,
        columns: [
          const DataColumn(label: Text('Service date')),
          const DataColumn(label: Text('Type')),
          const DataColumn(label: Text('Cost'), numeric: true),
          const DataColumn(label: Text('Vendor')),
          if (isFull) const DataColumn(label: Text('Odometer'), numeric: true),
          if (isFull) const DataColumn(label: Text('Notes')),
          if (isFull) const DataColumn(label: Text('Added')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final record in records)
            DataRow(
              key: ValueKey('maintenance.row.${record.id}'),
              cells: [
                DataCell(Text(Formatters.date(record.serviceDate))),
                DataCell(Text(record.maintenanceType.label)),
                DataCell(Text(Formatters.money(record.cost))),
                DataCell(
                  TableCellText(
                    Formatters.orMissing(record.vendorName),
                    maxWidth: 180,
                  ),
                ),
                if (isFull)
                  DataCell(
                    Text(
                      record.odometerKm == null
                          ? Formatters.missingValue
                          : '${Formatters.count(record.odometerKm!)} km',
                    ),
                  ),
                if (isFull)
                  DataCell(
                    TableCellText(
                      Formatters.orMissing(record.notes),
                      maxWidth: 200,
                    ),
                  ),
                if (isFull)
                  DataCell(
                    TableCellText(
                      _auditText(record),
                      key: ValueKey('maintenance.audit.${record.id}'),
                      maxWidth: 260,
                      style: small,
                    ),
                  ),
                DataCell(
                  _MaintenanceActions(
                    record: record,
                    isAdmin: isAdmin,
                    vehicleId: vehicleId,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Edit, and Delete for ADMIN, of one maintenance record.
class _MaintenanceActions extends ConsumerWidget {
  const _MaintenanceActions({
    required this.record,
    required this.isAdmin,
    required this.vehicleId,
  });

  final MaintenanceRecord record;
  final bool isAdmin;
  final int vehicleId;

  Future<void> _edit(BuildContext context) async {
    final saved = await showMaintenanceFormDialog(
      context,
      vehicleId: vehicleId,
      initial: record,
    );
    if (saved != null && context.mounted) {
      AppFeedback.success(context, 'Maintenance record updated.');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete maintenance record?',
      message:
          '${record.maintenanceType.label} on '
          '${Formatters.date(record.serviceDate)} '
          '(${Formatters.money(record.cost)}) will be permanently deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(maintenanceActionsProvider).delete(record);
      if (context.mounted) {
        AppFeedback.success(context, 'Maintenance record deleted.');
      }
    } on Exception catch (error) {
      if (context.mounted) {
        AppFeedback.error(
          context,
          MaintenanceActions.deleteErrorMessage(error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RowActions(
      keyPrefix: 'maintenance',
      id: record.id,
      isAdmin: isAdmin,
      onEdit: () => _edit(context),
      onDelete: () => _delete(context, ref),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({
    required this.record,
    required this.isAdmin,
    required this.vehicleId,
  });

  final MaintenanceRecord record;
  final bool isAdmin;
  final int vehicleId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final details = [
      Formatters.date(record.serviceDate),
      if (record.vendorName != null && record.vendorName!.trim().isNotEmpty)
        record.vendorName!,
      if (record.odometerKm != null)
        '${Formatters.count(record.odometerKm!)} km',
    ].join(' · ');
    final notes = record.notes?.trim();
    return Card(
      key: ValueKey('maintenance.record.${record.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        record.maintenanceType.label,
                        style: textTheme.titleMedium,
                      ),
                      Text(
                        Formatters.money(record.cost),
                        style: textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(details, style: textTheme.bodySmall),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(notes, style: textTheme.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _auditText(record),
                    key: ValueKey('maintenance.audit.${record.id}'),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _MaintenanceActions(
              record: record,
              isAdmin: isAdmin,
              vehicleId: vehicleId,
            ),
          ],
        ),
      ),
    );
  }
}
