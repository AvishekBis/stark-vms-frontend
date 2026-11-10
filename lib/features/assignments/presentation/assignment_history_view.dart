import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/page_response.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/data_table_frame.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/assignment.dart';
import 'assignment_providers.dart';

/// Whose history is shown: a vehicle's drivers or a driver's vehicles.
enum AssignmentPerspective { vehicle, driver }

/// Paginated assignment history; the current assignment is highlighted.
/// Cards below 600 px, a compact table up to 1024 px, the full table above
/// (guideline 14.2). It sits inside its parent's scroll view, so the table
/// only scrolls sideways.
class AssignmentHistoryView extends ConsumerStatefulWidget {
  const AssignmentHistoryView.forVehicle({super.key, required int vehicleId})
    : id = vehicleId,
      perspective = AssignmentPerspective.vehicle;

  const AssignmentHistoryView.forDriver({super.key, required int driverId})
    : id = driverId,
      perspective = AssignmentPerspective.driver;

  final int id;
  final AssignmentPerspective perspective;

  @override
  ConsumerState<AssignmentHistoryView> createState() =>
      _AssignmentHistoryViewState();
}

class _AssignmentHistoryViewState extends ConsumerState<AssignmentHistoryView> {
  int _page = 0;

  ProviderListenable<AsyncValue<PageResponse<Assignment>>> get _provider =>
      widget.perspective == AssignmentPerspective.vehicle
      ? vehicleAssignmentsProvider((vehicleId: widget.id, page: _page))
      : driverAssignmentsProvider((driverId: widget.id, page: _page));

  void _retry() {
    if (widget.perspective == AssignmentPerspective.vehicle) {
      ref.invalidate(
        vehicleAssignmentsProvider((vehicleId: widget.id, page: _page)),
      );
    } else {
      ref.invalidate(
        driverAssignmentsProvider((driverId: widget.id, page: _page)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVehicle = widget.perspective == AssignmentPerspective.vehicle;
    final screenSize = ScreenSize.fromWidth(MediaQuery.sizeOf(context).width);
    return AsyncValueView<PageResponse<Assignment>>(
      value: ref.watch(_provider),
      onRetry: _retry,
      loadingMessage: 'Loading assignment history…',
      isEmpty: (page) => page.totalElements == 0 && page.isEmpty,
      empty: EmptyView(
        icon: Icons.history,
        title: 'No assignment history yet',
        message: isVehicle
            ? 'Drivers assigned to this vehicle will appear here.'
            : 'Vehicles this driver drives will appear here.',
      ),
      data: (page) => Column(
        key: const Key('assignments.history'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (screenSize == ScreenSize.compact)
            for (final assignment in page.content)
              _AssignmentTile(assignment: assignment, isVehicle: isVehicle)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AssignmentTable(
                assignments: page.content,
                isVehicle: isVehicle,
                isFull: screenSize == ScreenSize.expanded,
              ),
            ),
          PaginationBar(
            page: page.page,
            totalPages: page.totalPages,
            totalElements: page.totalElements,
            pageSize: page.size,
            pageSizeOptions: const [],
            itemLabel: page.totalElements == 1 ? 'assignment' : 'assignments',
            onPageChanged: (value) => setState(() => _page = value),
            onPageSizeChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

void _openOther(
  BuildContext context,
  Assignment assignment, {
  required bool isVehicle,
}) {
  context.go(
    isVehicle
        ? AppRoutes.driverDetail(assignment.driverId)
        : AppRoutes.vehicleDetail(assignment.vehicleId),
  );
}

StatusBadge _stateBadge(Assignment assignment) => assignment.current
    ? const StatusBadge(label: 'Current', tone: StatusTone.success)
    : const StatusBadge(label: 'Ended', tone: StatusTone.neutral);

/// The tone of one entry: the running assignment is the success tone, a
/// closed one is neutral. The badge beside it always says which.
Color _toneOf(BuildContext context, Assignment assignment) {
  final colors = StatusColors.of(context);
  return assignment.current ? colors.success : colors.neutral;
}

/// The running assignment keeps a faint tint of its own tone; the other rows
/// get the hairline zebra and the gold veil under the pointer.
WidgetStateProperty<Color?> _rowColor(
  BuildContext context,
  int index,
  Assignment assignment,
) {
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.hovered)) {
      return AppPalette.goldTint;
    }
    if (assignment.current) {
      return _toneOf(context, assignment).withValues(alpha: 0.1);
    }
    return index.isOdd ? AppPalette.surfaceMuted : null;
  });
}

class _AssignmentTable extends StatelessWidget {
  const _AssignmentTable({
    required this.assignments,
    required this.isVehicle,
    required this.isFull,
  });

  final List<Assignment> assignments;
  final bool isVehicle;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    return DataTableFrame(
      scrollVertically: false,
      table: DataTable(
        key: const Key('assignments.table'),
        showCheckboxColumn: false,
        columnSpacing: AppSpacing.md,
        columns: [
          DataColumn(label: Text(isVehicle ? 'Driver' : 'Vehicle')),
          const DataColumn(label: Text('Assigned')),
          const DataColumn(label: Text('Unassigned')),
          const DataColumn(label: Text('State')),
          if (isFull) const DataColumn(label: Text('Assigned by')),
        ],
        rows: [
          for (final (index, assignment) in assignments.indexed)
            DataRow(
              key: ValueKey('assignment.row.${assignment.id}'),
              color: _rowColor(context, index, assignment),
              onSelectChanged: (_) =>
                  _openOther(context, assignment, isVehicle: isVehicle),
              cells: [
                DataCell(
                  Row(
                    children: [
                      IconPlate(
                        icon: isVehicle
                            ? Icons.person_outline
                            : Icons.directions_car_outlined,
                        tint: _toneOf(
                          context,
                          assignment,
                        ).withValues(alpha: 0.14),
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                      Text(
                        isVehicle
                            ? assignment.driverName
                            : assignment.vehicleNumber,
                      ),
                    ],
                  ),
                ),
                DataCell(Text(Formatters.dateTime(assignment.assignedAt))),
                DataCell(
                  Text(
                    assignment.current
                        ? 'now'
                        : Formatters.dateTime(assignment.unassignedAt),
                  ),
                ),
                DataCell(_stateBadge(assignment)),
                if (isFull)
                  DataCell(Text(Formatters.orMissing(assignment.assignedBy))),
              ],
            ),
        ],
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.assignment, required this.isVehicle});

  final Assignment assignment;
  final bool isVehicle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final period =
        '${Formatters.dateTime(assignment.assignedAt)} – '
        '${assignment.current ? 'now' : Formatters.dateTime(assignment.unassignedAt)}';
    final by = assignment.assignedBy == null
        ? ''
        : ' · assigned by ${assignment.assignedBy}';
    final tone = _toneOf(context, assignment);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      // One entry of the timeline: the tone on the leading edge and on the
      // icon plate, the badge spelling the state out.
      child: AccentEdgeCard(
        key: ValueKey('assignment.${assignment.id}'),
        accent: tone,
        onTap: () => _openOther(context, assignment, isVehicle: isVehicle),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconPlate(
                icon: isVehicle
                    ? Icons.person_outline
                    : Icons.directions_car_outlined,
                tint: tone.withValues(alpha: 0.14),
                size: 36,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVehicle
                          ? assignment.driverName
                          : assignment.vehicleNumber,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('$period$by', style: textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    _stateBadge(assignment),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
