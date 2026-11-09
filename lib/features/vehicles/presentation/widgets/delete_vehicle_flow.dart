import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/vehicle.dart';
import '../vehicle_providers.dart';

/// Confirms, deletes and reports the result (FR-V04).
/// Returns `true` when the vehicle was deleted.
Future<bool> confirmAndDeleteVehicle(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
) async {
  final confirmed = await ConfirmDialog.show(
    context,
    title: 'Delete vehicle?',
    message:
        'Vehicle ${vehicle.vehicleNumber} will be permanently deleted. This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return false;
  }
  try {
    await ref.read(vehicleActionsProvider).delete(vehicle);
    if (context.mounted) {
      AppFeedback.success(context, 'Vehicle ${vehicle.vehicleNumber} deleted.');
    }
    return true;
  } on Exception catch (error) {
    if (context.mounted) {
      AppFeedback.error(context, VehicleActions.deleteErrorMessage(error));
    }
    return false;
  }
}
