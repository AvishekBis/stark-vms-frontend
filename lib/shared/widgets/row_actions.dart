import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/status_colors.dart';

/// Edit and (for admins) delete icon buttons of a list row or card.
///
/// The buttons are keyed `'<keyPrefix>.edit.<id>'` and
/// `'<keyPrefix>.delete.<id>'`, e.g. `vehicle.edit.12`.
class RowActions extends StatelessWidget {
  const RowActions({
    super.key,
    required this.keyPrefix,
    required this.id,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  final String keyPrefix;
  final int id;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: ValueKey('$keyPrefix.edit.$id'),
          tooltip: 'Edit',
          onPressed: onEdit,
          color: AppPalette.navy,
          icon: const Icon(Icons.edit_outlined),
        ),
        if (isAdmin)
          IconButton(
            key: ValueKey('$keyPrefix.delete.$id'),
            tooltip: 'Delete',
            color: StatusColors.of(context).danger,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
  }
}
