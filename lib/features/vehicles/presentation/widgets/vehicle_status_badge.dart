import 'package:flutter/material.dart';

import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/vehicle_enums.dart';

/// Badge for a [VehicleStatus]: ACTIVE green, MAINTENANCE amber,
/// INACTIVE grey — always with the status text.
class VehicleStatusBadge extends StatelessWidget {
  const VehicleStatusBadge({super.key, required this.status});

  final VehicleStatus status;

  static StatusTone toneFor(VehicleStatus status) {
    return switch (status) {
      VehicleStatus.active => StatusTone.success,
      VehicleStatus.maintenance => StatusTone.warning,
      VehicleStatus.inactive => StatusTone.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    return StatusBadge(label: status.label, tone: toneFor(status));
  }
}
