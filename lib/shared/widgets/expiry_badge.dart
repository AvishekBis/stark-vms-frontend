import 'package:flutter/material.dart';

import '../models/expiry_status.dart';
import 'status_badge.dart';

/// Green VALID / amber EXPIRING_SOON / red EXPIRED badge — always with text
/// such as "Expires in 12 days" (FR-D02, guideline 14.2).
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.status, this.daysUntilExpiry});

  final ExpiryStatus status;
  final int? daysUntilExpiry;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: status.describe(daysUntilExpiry),
      tone: status.tone,
    );
  }
}
