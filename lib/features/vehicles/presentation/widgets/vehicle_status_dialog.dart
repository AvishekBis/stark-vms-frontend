import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/vehicle.dart';
import '../../data/vehicle_enums.dart';
import '../vehicle_providers.dart';
import 'vehicle_status_badge.dart';

/// Asks for the new status and changes it (ADMIN, FR-V07). Returns the
/// updated vehicle, or `null` when nothing changed.
Future<Vehicle?> changeVehicleStatus(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle, {
  VehicleStatus? preselected,
}) async {
  final chosen = await showDialog<VehicleStatus>(
    context: context,
    builder: (_) =>
        VehicleStatusDialog(vehicle: vehicle, preselected: preselected),
  );
  if (chosen == null || chosen == vehicle.status || !context.mounted) {
    return null;
  }
  try {
    final updated = await ref
        .read(vehicleActionsProvider)
        .changeStatus(vehicle, chosen);
    if (context.mounted) {
      AppFeedback.success(
        context,
        'Vehicle ${vehicle.vehicleNumber} is now ${chosen.label.toLowerCase()}.',
      );
    }
    return updated;
  } on Exception catch (error) {
    if (context.mounted) {
      AppFeedback.error(context, VehicleActions.statusErrorMessage(error));
    }
    return null;
  }
}

/// The three statuses (BR-04). Choosing INACTIVE warns that the current
/// driver will be unassigned (BR-05).
class VehicleStatusDialog extends StatefulWidget {
  const VehicleStatusDialog({
    super.key,
    required this.vehicle,
    this.preselected,
  });

  final Vehicle vehicle;
  final VehicleStatus? preselected;

  @override
  State<VehicleStatusDialog> createState() => _VehicleStatusDialogState();
}

class _VehicleStatusDialogState extends State<VehicleStatusDialog> {
  late VehicleStatus _selected = widget.preselected ?? widget.vehicle.status;

  static String _meaning(VehicleStatus status) => switch (status) {
    VehicleStatus.active => 'In service; a driver can be assigned.',
    VehicleStatus.maintenance =>
      'In the workshop; the current driver stays assigned.',
    VehicleStatus.inactive => 'Out of service; cannot get a driver.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driver = widget.vehicle.currentDriver;
    final warnInactive = widget.vehicle.endsAssignmentOn(_selected);

    return AlertDialog(
      key: const Key('statusDialog'),
      scrollable: true,
      title: Text('Change status of ${widget.vehicle.vehicleNumber}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.dialogMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final status in VehicleStatus.values)
              ListTile(
                key: ValueKey('statusDialog.${status.apiValue}'),
                selected: status == _selected,
                leading: Icon(
                  status == _selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Align(
                  alignment: Alignment.centerLeft,
                  child: VehicleStatusBadge(status: status),
                ),
                subtitle: Text(_meaning(status)),
                onTap: () => setState(() => _selected = status),
              ),
            if (warnInactive) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                driver == null
                    ? 'An inactive vehicle cannot be assigned a driver until it '
                          'is active again.'
                    : 'Setting the vehicle INACTIVE will unassign its driver '
                          '${driver.fullName}. The assignment stays in the history.',
                key: const Key('statusDialog.inactiveWarning'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('statusDialog.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('statusDialog.save'),
          onPressed: _selected == widget.vehicle.status
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Change status'),
        ),
      ],
    );
  }
}
