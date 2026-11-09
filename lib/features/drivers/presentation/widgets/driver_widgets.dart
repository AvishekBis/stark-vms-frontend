import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/expiry_badge.dart';
import '../../../../shared/widgets/feedback.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/driver.dart';
import '../driver_providers.dart';

/// ACTIVE green, INACTIVE grey — always with text.
class DriverStatusBadge extends StatelessWidget {
  const DriverStatusBadge({super.key, required this.status});

  final DriverStatus status;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(label: status.label, tone: toneFor(status));
  }

  static StatusTone toneFor(DriverStatus status) {
    return switch (status) {
      DriverStatus.active => StatusTone.success,
      DriverStatus.inactive => StatusTone.neutral,
    };
  }
}

/// The licence expiry badge of a driver (FR-X02).
class LicenseExpiryBadge extends StatelessWidget {
  const LicenseExpiryBadge({super.key, required this.driver});

  final Driver driver;

  @override
  Widget build(BuildContext context) {
    return ExpiryBadge(
      status: driver.licenseStatus,
      daysUntilExpiry: driver.daysUntilLicenseExpiry,
    );
  }
}

/// Confirms and deletes a driver. A driver with assignment history cannot
/// be deleted (409 `driver-has-history`); the dialog then offers to set
/// the driver INACTIVE instead. Returns `true` when the driver was deleted.
Future<bool> confirmAndDeleteDriver(
  BuildContext context,
  WidgetRef ref,
  Driver driver,
) async {
  final confirmed = await ConfirmDialog.show(
    context,
    title: 'Delete driver?',
    message:
        'Driver ${driver.fullName} will be permanently deleted. This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed || !context.mounted) {
    return false;
  }
  try {
    await ref.read(driverActionsProvider).delete(driver);
    if (context.mounted) {
      AppFeedback.success(context, 'Driver ${driver.fullName} deleted.');
    }
    return true;
  } on ApiException catch (error) {
    if (!context.mounted) {
      return false;
    }
    if (DriverActions.hasHistory(error) && driver.isActive) {
      final deactivate = await ConfirmDialog.show(
        context,
        title: 'Driver has history',
        message: error.message,
        confirmLabel: 'Set INACTIVE instead',
      );
      if (deactivate && context.mounted) {
        await _deactivate(context, ref, driver);
      }
      return false;
    }
    AppFeedback.error(context, DriverActions.deleteErrorMessage(error));
    return false;
  }
}

Future<void> _deactivate(
  BuildContext context,
  WidgetRef ref,
  Driver driver,
) async {
  try {
    await ref.read(driverActionsProvider).deactivate(driver);
    if (context.mounted) {
      AppFeedback.success(context, '${driver.fullName} is now inactive.');
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      AppFeedback.error(context, error.message);
    }
  }
}
