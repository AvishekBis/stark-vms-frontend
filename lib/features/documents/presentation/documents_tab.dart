import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/data_table_frame.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/expiry_badge.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/vehicle_document.dart';
import 'document_providers.dart';
import 'upload_document_dialog.dart';

/// Documents of one vehicle (FR-D01, FR-D02): soonest expiry first, with
/// expiry badges, View / Download, Delete (ADMIN) and Upload.
class DocumentsTab extends ConsumerWidget {
  const DocumentsTab({
    super.key,
    required this.vehicleId,
    required this.vehicleNumber,
  });

  final int vehicleId;
  final String vehicleNumber;

  Future<void> _upload(BuildContext context) async {
    final document = await showUploadDocumentDialog(
      context,
      vehicleId: vehicleId,
      vehicleNumber: vehicleNumber,
    );
    if (document != null && context.mounted) {
      AppFeedback.success(
        context,
        '${document.documentType.label} uploaded · '
        '${document.expiryStatus.describe(document.daysUntilExpiry)}.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(vehicleDocumentsProvider(vehicleId));
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final screenSize = ScreenSize.fromWidth(MediaQuery.sizeOf(context).width);

    final uploadButton = FilledButton.icon(
      key: const Key('documents.upload'),
      onPressed: () => _upload(context),
      icon: const Icon(Icons.upload_file),
      label: const Text('Upload document'),
    );

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
              Text(
                documents.hasValue
                    ? '${documents.requireValue.length} '
                          '${documents.requireValue.length == 1 ? 'document' : 'documents'}'
                    : 'Documents',
                key: const Key('documents.count'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              uploadButton,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AsyncValueView<List<VehicleDocument>>(
              value: documents,
              onRetry: () =>
                  ref.invalidate(vehicleDocumentsProvider(vehicleId)),
              loadingMessage: 'Loading documents…',
              isEmpty: (list) => list.isEmpty,
              empty: const EmptyView(
                icon: Icons.description_outlined,
                title: 'No documents yet',
                message:
                    'Upload the registration, tax token, insurance and other '
                    'papers to track their expiry.',
              ),
              data: (list) => screenSize == ScreenSize.compact
                  ? ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) => _DocumentCard(
                        document: list[index],
                        isAdmin: isAdmin,
                      ),
                    )
                  : _DocumentTable(
                      documents: list,
                      isAdmin: isAdmin,
                      isFull: screenSize == ScreenSize.expanded,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTable extends StatelessWidget {
  const _DocumentTable({
    required this.documents,
    required this.isAdmin,
    required this.isFull,
  });

  final List<VehicleDocument> documents;
  final bool isAdmin;
  final bool isFull;

  @override
  Widget build(BuildContext context) {
    return DataTableFrame(
      table: DataTable(
        key: const Key('documents.table'),
        columnSpacing: AppSpacing.md,
        columns: [
          const DataColumn(label: Text('Type')),
          const DataColumn(label: Text('Number')),
          if (isFull) const DataColumn(label: Text('Issued')),
          const DataColumn(label: Text('Expires')),
          const DataColumn(label: Text('Status')),
          if (isFull) const DataColumn(label: Text('File')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final document in documents)
            DataRow(
              key: ValueKey('document.row.${document.id}'),
              cells: [
                DataCell(Text(document.documentType.label)),
                DataCell(Text(Formatters.orMissing(document.documentNumber))),
                if (isFull) DataCell(Text(Formatters.date(document.issueDate))),
                DataCell(Text(Formatters.date(document.expiryDate))),
                DataCell(
                  ExpiryBadge(
                    status: document.expiryStatus,
                    daysUntilExpiry: document.daysUntilExpiry,
                  ),
                ),
                if (isFull)
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${Formatters.orMissing(document.fileName)} · '
                          '${Formatters.fileSize(document.fileSize)}',
                        ),
                        // FR-X01: when and by whom it was uploaded.
                        Text(
                          '${Formatters.date(document.createdAt)} · '
                          '${Formatters.orMissing(document.createdBy)}',
                          key: ValueKey('document.audit.${document.id}'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                DataCell(
                  DocumentActionButtons(document: document, isAdmin: isAdmin),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document, required this.isAdmin});

  final VehicleDocument document;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final details = [
      if (document.documentNumber != null) document.documentNumber!,
      'expires ${Formatters.date(document.expiryDate)}',
      Formatters.fileSize(document.fileSize),
    ].join(' · ');
    return Card(
      key: ValueKey('document.card.${document.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(document.documentType.label, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(details, style: textTheme.bodySmall),
            Text(
              Formatters.audit(
                'Uploaded',
                at: document.createdAt,
                by: document.createdBy,
              ),
              key: ValueKey('document.audit.${document.id}'),
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ExpiryBadge(
                  status: document.expiryStatus,
                  daysUntilExpiry: document.daysUntilExpiry,
                ),
                DocumentActionButtons(document: document, isAdmin: isAdmin),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// View / Download / Delete (ADMIN) for one document.
class DocumentActionButtons extends ConsumerWidget {
  const DocumentActionButtons({
    super.key,
    required this.document,
    required this.isAdmin,
  });

  final VehicleDocument document;
  final bool isAdmin;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String fallback, {
    String? forbidden,
  }) async {
    try {
      await action();
    } on Exception catch (error) {
      if (context.mounted) {
        AppFeedback.error(
          context,
          DocumentActions.errorMessage(
            error,
            fallback: fallback,
            forbidden: forbidden,
          ),
        );
      }
    } on UnsupportedError {
      if (context.mounted) {
        AppFeedback.error(context, fallback);
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete document?',
      message:
          '${document.documentType.label} '
          '${document.documentNumber ?? ''} and its file will be permanently '
          'deleted. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    await _run(
      context,
      () async {
        await ref.read(documentActionsProvider).delete(document);
        if (context.mounted) {
          AppFeedback.success(
            context,
            '${document.documentType.label} deleted.',
          );
        }
      },
      'The document could not be deleted. Please try again.',
      forbidden: DocumentActions.deleteForbiddenMessage,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(documentActionsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('document.view.${document.id}'),
          tooltip: 'View',
          icon: const Icon(Icons.visibility_outlined),
          onPressed: () => _run(
            context,
            () => actions.view(document),
            'The file could not be opened. Please try again.',
          ),
        ),
        IconButton(
          key: ValueKey('document.download.${document.id}'),
          tooltip: 'Download',
          icon: const Icon(Icons.download_outlined),
          onPressed: () => _run(
            context,
            () => actions.download(document),
            'The file could not be downloaded. Please try again.',
          ),
        ),
        if (isAdmin)
          IconButton(
            key: ValueKey('document.delete.${document.id}'),
            tooltip: 'Delete',
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
      ],
    );
  }
}
