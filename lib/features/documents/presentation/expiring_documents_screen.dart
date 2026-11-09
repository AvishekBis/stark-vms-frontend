import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/page_response.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/data_table_frame.dart';
import '../../../shared/widgets/expiry_badge.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/state_views.dart';
import '../../vehicles/presentation/vehicle_detail_tab.dart';
import '../data/vehicle_document.dart';
import 'document_providers.dart';

/// Fleet-wide expired and expiring documents (FR-D02), paginated, with a
/// 7 / 30 / 60 / 90 day window. Cards below 600 px, a compact table up to
/// 1024 px, the full table above (guideline 14.2).
class ExpiringDocumentsScreen extends ConsumerStatefulWidget {
  const ExpiringDocumentsScreen({super.key, this.initialWithinDays});

  /// From `/documents/expiring?withinDays=60`.
  final int? initialWithinDays;

  @override
  ConsumerState<ExpiringDocumentsScreen> createState() =>
      _ExpiringDocumentsScreenState();
}

class _ExpiringDocumentsScreenState
    extends ConsumerState<ExpiringDocumentsScreen> {
  @override
  void initState() {
    super.initState();
    final days = widget.initialWithinDays;
    if (days != null &&
        ExpiringDocumentsQuery.withinDaysOptions.contains(days)) {
      // Applied after the first frame: providers may not change mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(expiringDocumentsQueryProvider.notifier).showWithin(days);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(expiringDocumentsQueryProvider);
    final value = ref.watch(expiringDocumentsProvider);
    final controller = ref.read(expiringDocumentsQueryProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final screenSize = ScreenSize.fromWidth(MediaQuery.sizeOf(context).width);

    return Scaffold(
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                Text('Expiring documents', style: textTheme.headlineSmall),
                SegmentedButton<int>(
                  key: const Key('expiring.withinDays'),
                  showSelectedIcon: false,
                  segments: [
                    for (final days in ExpiringDocumentsQuery.withinDaysOptions)
                      ButtonSegment<int>(
                        value: days,
                        label: Text('$days days'),
                      ),
                  ],
                  selected: {query.withinDays},
                  onSelectionChanged: (selection) =>
                      controller.setWithinDays(selection.first),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Expired documents and documents that expire within '
              '${query.withinDays} days, soonest first.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSpacing.xs,
              child: value.isLoading && value.hasValue
                  ? const LinearProgressIndicator()
                  : null,
            ),
            Expanded(
              child: AsyncValueView<PageResponse<VehicleDocument>>(
                value: value,
                onRetry: () => ref.invalidate(expiringDocumentsProvider),
                isEmpty: (page) => page.totalElements == 0 && page.isEmpty,
                empty: EmptyView(
                  icon: Icons.verified_outlined,
                  title: 'Nothing expires within ${query.withinDays} days',
                  message: 'No document is expired either.',
                ),
                data: (page) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: screenSize == ScreenSize.compact
                          ? ListView.separated(
                              itemCount: page.content.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) =>
                                  ExpiringDocumentTile(
                                    document: page.content[index],
                                  ),
                            )
                          : _ExpiringDocumentsTable(
                              documents: page.content,
                              isFull: screenSize == ScreenSize.expanded,
                            ),
                    ),
                    PaginationBar(
                      page: page.page,
                      totalPages: page.totalPages,
                      totalElements: page.totalElements,
                      pageSize: query.size,
                      pageSizeOptions: ExpiringDocumentsQuery.pageSizeOptions,
                      itemLabel: page.totalElements == 1
                          ? 'document'
                          : 'documents',
                      onPageChanged: controller.goToPage,
                      onPageSizeChanged: controller.setPageSize,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openDocuments(BuildContext context, VehicleDocument document) {
  context.go(
    AppRoutes.vehicleDetail(
      document.vehicleId,
      tab: VehicleDetailTab.documents.queryValue,
    ),
  );
}

class _ExpiringDocumentsTable extends StatelessWidget {
  const _ExpiringDocumentsTable({
    required this.documents,
    required this.isFull,
  });

  final List<VehicleDocument> documents;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    return DataTableFrame(
      table: DataTable(
        key: const Key('expiring.table'),
        showCheckboxColumn: false,
        columnSpacing: AppSpacing.md,
        columns: [
          const DataColumn(label: Text('Vehicle')),
          const DataColumn(label: Text('Type')),
          if (isFull) const DataColumn(label: Text('Number')),
          if (isFull) const DataColumn(label: Text('Issued')),
          const DataColumn(label: Text('Expires')),
          const DataColumn(label: Text('Status')),
        ],
        rows: [
          for (final document in documents)
            DataRow(
              key: ValueKey('expiring.row.${document.id}'),
              onSelectChanged: (_) => _openDocuments(context, document),
              cells: [
                DataCell(Text(document.vehicleNumber)),
                DataCell(Text(document.documentType.label)),
                if (isFull)
                  DataCell(Text(Formatters.orMissing(document.documentNumber))),
                if (isFull) DataCell(Text(Formatters.date(document.issueDate))),
                DataCell(Text(Formatters.date(document.expiryDate))),
                DataCell(
                  ExpiryBadge(
                    status: document.expiryStatus,
                    daysUntilExpiry: document.daysUntilExpiry,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One expiring document; tapping opens the vehicle's Documents tab.
class ExpiringDocumentTile extends StatelessWidget {
  const ExpiringDocumentTile({super.key, required this.document});

  final VehicleDocument document;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      document.vehicleNumber,
      if (document.documentNumber != null) document.documentNumber!,
      'expires ${Formatters.date(document.expiryDate)}',
    ].join(' · ');
    return Card(
      key: ValueKey('expiring.document.${document.id}'),
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(document.documentType.label),
        subtitle: Text(subtitle),
        trailing: ExpiryBadge(
          status: document.expiryStatus,
          daysUntilExpiry: document.daysUntilExpiry,
        ),
        onTap: () => _openDocuments(context, document),
      ),
    );
  }
}
