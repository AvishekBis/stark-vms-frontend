import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/page_response.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/data_table_frame.dart';
import '../../../shared/widgets/expiry_badge.dart';
import '../../../shared/widgets/pagination_bar.dart';
import '../../../shared/widgets/state_views.dart';
import '../../vehicles/presentation/vehicle_detail_tab.dart';
import '../data/vehicle_document.dart';
import 'document_providers.dart';
import 'documents_tab.dart';

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
            // The page opens on the navy banner; the window picker sits just
            // under it, where it keeps the full page width on a 360 px phone.
            PageHeader(
              title: 'Expiring documents',
              icon: Icons.event_note_outlined,
              dense: screenSize == ScreenSize.compact,
              subtitle:
                  'Expired documents and documents that expire within '
                  '${query.withinDays} days, soonest first.',
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                key: const Key('expiring.withinDays'),
                showSelectedIcon: false,
                segments: [
                  for (final days in ExpiringDocumentsQuery.withinDaysOptions)
                    ButtonSegment<int>(value: days, label: Text('$days days')),
                ],
                selected: {query.withinDays},
                onSelectionChanged: (selection) =>
                    controller.setWithinDays(selection.first),
              ),
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
          for (final (index, document) in documents.indexed)
            DataRow(
              key: ValueKey('expiring.row.${document.id}'),
              color: DataTableFrame.zebraRow(index),
              onSelectChanged: (_) => _openDocuments(context, document),
              cells: [
                DataCell(Text(document.vehicleNumber)),
                DataCell(
                  DocumentTypeCell(
                    status: document.expiryStatus,
                    label: document.documentType.label,
                  ),
                ),
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
    final textTheme = Theme.of(context).textTheme;
    final tone = StatusColors.of(context)
        .background(document.expiryStatus.tone);
    return AccentEdgeCard(
      key: ValueKey('expiring.document.${document.id}'),
      accent: tone,
      onTap: () => _openDocuments(context, document),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconPlate(
              icon: documentStatusIcon(document.expiryStatus),
              tint: tone.withValues(alpha: 0.14),
              color: tone,
              size: 38,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.documentType.label,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  // The badge keeps its words, so the tone of the card
                  // edge and the plate is never the only signal.
                  ExpiryBadge(
                    status: document.expiryStatus,
                    daysUntilExpiry: document.daysUntilExpiry,
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
