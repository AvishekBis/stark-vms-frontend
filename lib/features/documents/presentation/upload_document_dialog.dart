import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/date_form_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../data/document_file_picker.dart';
import '../data/vehicle_document.dart';
import 'document_providers.dart';

/// Opens the upload dialog (FR-D01). Resolves to the uploaded document, or
/// `null` when cancelled.
Future<VehicleDocument?> showUploadDocumentDialog(
  BuildContext context, {
  required int vehicleId,
  required String vehicleNumber,
}) {
  return showDialog<VehicleDocument>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UploadDocumentDialog(
      vehicleId: vehicleId,
      vehicleNumber: vehicleNumber,
    ),
  );
}

/// Type, number, issue / expiry dates and a PDF / JPG / PNG file up to
/// 5 MB, checked here first (BR-07) and again by the server (400 / 413).
class UploadDocumentDialog extends ConsumerStatefulWidget {
  const UploadDocumentDialog({
    super.key,
    required this.vehicleId,
    required this.vehicleNumber,
  });

  final int vehicleId;
  final String vehicleNumber;

  @override
  ConsumerState<UploadDocumentDialog> createState() =>
      _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends ConsumerState<UploadDocumentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _number = TextEditingController();
  DocumentType? _type;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  PickedFile? _file;
  String? _fileError;
  bool _picking = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final file = await ref.read(documentFilePickerProvider).pick();
      if (!mounted) {
        return;
      }
      setState(() {
        if (file != null) {
          _file = file;
          _fileError = DocumentUploadRules.fileError(file);
          ref
              .read(documentUploadControllerProvider.notifier)
              .clearFieldError('file');
        }
      });
    } on Exception {
      if (mounted) {
        AppFeedback.error(context, 'The file could not be read. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  Future<void> _submit() async {
    final fileError = DocumentUploadRules.fileError(_file);
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _fileError = fileError;
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });
    if (!formValid || fileError != null) {
      return;
    }
    final document = await ref
        .read(documentUploadControllerProvider.notifier)
        .submit(
          widget.vehicleId,
          DocumentUpload(
            documentType: _type!,
            documentNumber: _number.text,
            issueDate: _issueDate,
            expiryDate: _expiryDate!,
            file: _file!,
          ),
        );
    if (document != null && mounted) {
      Navigator.of(context).pop(document);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentUploadControllerProvider);
    final controller = ref.read(documentUploadControllerProvider.notifier);
    final today = ref.watch(clockProvider).now();
    final theme = Theme.of(context);
    final file = _file;
    final fileError = _fileError ?? state.errorFor('file');
    final generalError = state.errorMessage;

    return AlertDialog(
      key: const Key('uploadDialog'),
      title: Text('Upload document · ${widget.vehicleNumber}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.dialogMaxWidth),
        child: SizedBox(
          width: AppSpacing.dialogMaxWidth,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<DocumentType>(
                    key: const Key('uploadDialog.type'),
                    initialValue: _type,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Document type *',
                      errorText: state.errorFor('documentType'),
                    ),
                    items: [
                      for (final type in DocumentType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? 'Document type is required.' : null,
                    onChanged: (value) {
                      setState(() => _type = value);
                      controller.clearFieldError('documentType');
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('uploadDialog.number'),
                    controller: _number,
                    decoration: InputDecoration(
                      labelText: 'Document number',
                      hintText: 'e.g. TT-2026-0099',
                      errorText: state.errorFor('documentNumber'),
                    ),
                    validator: DocumentUploadRules.documentNumberError,
                    onChanged: (_) =>
                        controller.clearFieldError('documentNumber'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DateFormField(
                    key: const Key('uploadDialog.issueDate'),
                    label: 'Issue date',
                    clearable: true,
                    firstDate: DateTime(today.year - 30),
                    lastDate: DateTime(today.year + 30),
                    errorText: state.errorFor('issueDate'),
                    onChanged: (value) {
                      _issueDate = value;
                      controller.clearFieldError('issueDate');
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DateFormField(
                    key: const Key('uploadDialog.expiryDate'),
                    label: 'Expiry date *',
                    firstDate: DateTime(today.year - 30),
                    lastDate: DateTime(today.year + 30),
                    errorText: state.errorFor('expiryDate'),
                    validator: (value) => DocumentUploadRules.expiryError(
                      issueDate: _issueDate,
                      expiryDate: value,
                    ),
                    onChanged: (value) {
                      _expiryDate = value;
                      controller.clearFieldError('expiryDate');
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'File * (PDF, JPG or PNG, max 5 MB)',
                      errorText: fileError,
                      errorMaxLines: 2,
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          file == null
                              ? 'No file chosen'
                              : '${file.name} · ${Formatters.fileSize(file.size)}',
                          key: const Key('uploadDialog.fileName'),
                          overflow: TextOverflow.ellipsis,
                        ),
                        OutlinedButton.icon(
                          key: const Key('uploadDialog.pickFile'),
                          onPressed: _picking || state.isSubmitting
                              ? null
                              : _pickFile,
                          icon: const Icon(Icons.attach_file),
                          label: Text(file == null ? 'Choose file' : 'Change'),
                        ),
                      ],
                    ),
                  ),
                  if (generalError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      generalError,
                      key: const Key('uploadDialog.error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('uploadDialog.cancel'),
          onPressed: state.isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('uploadDialog.submit'),
          onPressed: state.isSubmitting || _picking ? null : _submit,
          icon: state.isSubmitting
              ? const SizedBox.square(
                  dimension: AppSpacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          label: const Text('Upload'),
        ),
      ],
    );
  }
}
