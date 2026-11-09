import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/date_form_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/stale_version_dialog.dart';
import '../data/maintenance_record.dart';
import 'maintenance_providers.dart';

/// Opens the add / edit maintenance dialog (FR-M01). Resolves to the saved
/// record, or `null` when cancelled.
Future<MaintenanceRecord?> showMaintenanceFormDialog(
  BuildContext context, {
  required int vehicleId,
  MaintenanceRecord? initial,
}) {
  return showDialog<MaintenanceRecord>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        MaintenanceFormDialog(vehicleId: vehicleId, initial: initial),
  );
}

class MaintenanceFormDialog extends ConsumerStatefulWidget {
  const MaintenanceFormDialog({
    super.key,
    required this.vehicleId,
    this.initial,
  });

  final int vehicleId;
  final MaintenanceRecord? initial;

  @override
  ConsumerState<MaintenanceFormDialog> createState() =>
      _MaintenanceFormDialogState();
}

class _MaintenanceFormDialogState extends ConsumerState<MaintenanceFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _vendor = TextEditingController();
  final TextEditingController _odometer = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  DateTime? _serviceDate;
  MaintenanceType? _type;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  /// The record being edited (`null` when adding). Replaced by the fresh
  /// record after "Reload" (409 stale-version), so its `version` is sent.
  MaintenanceRecord? _record;

  /// Bumped on reload so the date and type fields take the new values.
  int _generation = 0;

  bool get _isEdit => _record != null;

  @override
  void initState() {
    super.initState();
    _fill(widget.initial);
  }

  void _fill(MaintenanceRecord? record) {
    _record = record;
    _cost.text = record == null ? '' : record.cost.toStringAsFixed(2);
    _vendor.text = record?.vendorName ?? '';
    _odometer.text = record?.odometerKm?.toString() ?? '';
    _notes.text = record?.notes ?? '';
    _serviceDate = record?.serviceDate;
    _type = record?.maintenanceType;
  }

  @override
  void dispose() {
    _cost.dispose();
    _vendor.dispose();
    _odometer.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final odometer = _odometer.text.trim();
    final controller = ref.read(maintenanceFormControllerProvider.notifier);
    final saved = await controller.submit(
      vehicleId: widget.vehicleId,
      existing: _record,
      input: MaintenanceInput(
        serviceDate: _serviceDate!,
        maintenanceType: _type!,
        cost: MaintenanceValidators.parseCost(_cost.text),
        vendorName: _vendor.text,
        odometerKm: odometer.isEmpty ? null : int.parse(odometer),
        notes: _notes.text,
      ),
    );
    if (!mounted) {
      return;
    }
    if (saved != null) {
      Navigator.of(context).pop(saved);
      return;
    }
    final staleMessage = ref
        .read(maintenanceFormControllerProvider)
        .staleVersionMessage;
    if (staleMessage != null) {
      controller.clearStaleVersion();
      await _offerReload(staleMessage);
    }
  }

  /// 409 stale-version (ADR 0023): Reload refetches the record and refills
  /// the form (local edits are discarded); Cancel keeps the edits.
  Future<void> _offerReload(String message) async {
    final record = _record;
    final reload = await StaleVersionDialog.show(context, message: message);
    if (!reload || !mounted || record == null) {
      return;
    }
    try {
      final fresh = await ref
          .read(maintenanceFormControllerProvider.notifier)
          .reload(record.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _fill(fresh);
        _generation++;
        _autovalidateMode = AutovalidateMode.disabled;
      });
      AppFeedback.success(context, StaleVersionDialog.reloadedMessage);
    } on ApiException catch (error) {
      if (mounted) {
        AppFeedback.error(context, error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceFormControllerProvider);
    final controller = ref.read(maintenanceFormControllerProvider.notifier);
    // "Not after today" uses the server's Asia/Dhaka date (BR-09).
    final today = Dates.businessToday(ref.watch(clockProvider).now());
    final theme = Theme.of(context);
    final generalError = state.errorMessage;

    return AlertDialog(
      key: const Key('maintenanceDialog'),
      title: Text(
        _isEdit ? 'Edit maintenance record' : 'Add maintenance record',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.dialogMaxWidth),
        child: SizedBox(
          width: AppSpacing.dialogMaxWidth,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              autovalidateMode: _autovalidateMode,
              child: Column(
                key: ValueKey(_generation),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DateFormField(
                    key: const Key('maintenanceDialog.serviceDate'),
                    label: 'Service date *',
                    initialValue: _serviceDate,
                    firstDate: DateTime(today.year - 30),
                    lastDate: DateTime(today.year, today.month, today.day),
                    errorText: state.errorFor('serviceDate'),
                    validator: (value) =>
                        MaintenanceValidators.serviceDate(value, today: today),
                    onChanged: (value) {
                      _serviceDate = value;
                      controller.clearFieldError('serviceDate');
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<MaintenanceType>(
                    key: const Key('maintenanceDialog.type'),
                    initialValue: _type,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Maintenance type *',
                      errorText: state.errorFor('maintenanceType'),
                    ),
                    items: [
                      for (final type in MaintenanceType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? 'Maintenance type is required.' : null,
                    onChanged: (value) {
                      setState(() => _type = value);
                      controller.clearFieldError('maintenanceType');
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('maintenanceDialog.cost'),
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Cost (${Formatters.currency}) *',
                      hintText: 'e.g. 3500.00',
                      errorText: state.errorFor('cost'),
                      errorMaxLines: 2,
                    ),
                    validator: MaintenanceValidators.cost,
                    onChanged: (_) => controller.clearFieldError('cost'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('maintenanceDialog.vendor'),
                    controller: _vendor,
                    decoration: InputDecoration(
                      labelText: 'Workshop / vendor',
                      hintText: 'e.g. Navana Service Centre',
                      errorText: state.errorFor('vendorName'),
                    ),
                    validator: MaintenanceValidators.vendor,
                    onChanged: (_) => controller.clearFieldError('vendorName'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('maintenanceDialog.odometer'),
                    controller: _odometer,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Odometer (km)',
                      errorText: state.errorFor('odometerKm'),
                    ),
                    validator: MaintenanceValidators.odometer,
                    onChanged: (_) => controller.clearFieldError('odometerKm'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('maintenanceDialog.notes'),
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      errorText: state.errorFor('notes'),
                    ),
                    validator: MaintenanceValidators.notes,
                    onChanged: (_) => controller.clearFieldError('notes'),
                  ),
                  if (generalError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      generalError,
                      key: const Key('maintenanceDialog.error'),
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
          key: const Key('maintenanceDialog.cancel'),
          onPressed: state.isSubmitting
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('maintenanceDialog.save'),
          onPressed: state.isSubmitting ? null : _submit,
          icon: state.isSubmitting
              ? const SizedBox.square(
                  dimension: AppSpacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isEdit ? 'Save changes' : 'Add record'),
        ),
      ],
    );
  }
}
