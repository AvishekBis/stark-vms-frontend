import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../data/vehicle.dart';
import '../../data/vehicle_enums.dart';
import '../vehicle_providers.dart';

/// Confirms, deletes and reports the result (FR-V04).
///
/// A vehicle with documents, maintenance or driver history cannot be
/// deleted (BR-10, 409 `vehicle-has-history`): the server's explanation is
/// shown with a "Set INACTIVE instead" action (delete is ADMIN-only, and
/// so is the status change). Returns `true` when the vehicle was deleted.
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
    if (!context.mounted) {
      return false;
    }
    if (VehicleActions.hasHistory(error)) {
      await _offerInactive(context, ref, vehicle, error as ApiException);
      return false;
    }
    AppFeedback.error(context, VehicleActions.deleteErrorMessage(error));
    return false;
  }
}

Future<void> _offerInactive(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
  ApiException error,
) async {
  final alreadyInactive = vehicle.status == VehicleStatus.inactive;
  final setInactive = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('vehicleHistoryDialog'),
      title: Text(error.title ?? 'Vehicle has history'),
      content: Text(error.message),
      actions: [
        TextButton(
          key: const Key('vehicleHistoryDialog.close'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(alreadyInactive ? 'OK' : 'Keep as is'),
        ),
        if (!alreadyInactive)
          FilledButton(
            key: const Key('vehicleHistoryDialog.setInactive'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Set INACTIVE instead'),
          ),
      ],
    ),
  );
  if (setInactive != true || !context.mounted) {
    return;
  }
  try {
    await ref
        .read(vehicleActionsProvider)
        .changeStatus(vehicle, VehicleStatus.inactive);
    if (context.mounted) {
      AppFeedback.success(
        context,
        'Vehicle ${vehicle.vehicleNumber} is now inactive.',
      );
    }
  } on Exception catch (statusError) {
    if (context.mounted) {
      AppFeedback.error(
        context,
        VehicleActions.statusErrorMessage(statusError),
      );
    }
  }
}
