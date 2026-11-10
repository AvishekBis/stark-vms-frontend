import 'package:flutter/material.dart';

import '../../core/network/sort_direction.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';

/// A "Sort" chip that opens a menu of every field and direction. Lists use
/// it on narrow screens too, where there are no column headers to tap.
class SortMenu<F> extends StatelessWidget {
  const SortMenu({
    super.key,
    required this.values,
    required this.label,
    required this.field,
    required this.direction,
    required this.onSelected,
  });

  final List<F> values;
  final String Function(F field) label;
  final F field;
  final SortDirection direction;
  final void Function(F field, SortDirection direction) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<(F, SortDirection)>(
      tooltip: 'Sort',
      onSelected: (choice) => onSelected(choice.$1, choice.$2),
      itemBuilder: (context) => [
        for (final option in values)
          for (final optionDirection in SortDirection.values)
            CheckedPopupMenuItem<(F, SortDirection)>(
              value: (option, optionDirection),
              checked: option == field && optionDirection == direction,
              child: SortLabel(
                label: label(option),
                direction: optionDirection,
              ),
            ),
      ],
      child: Chip(
        avatar: const Icon(Icons.sort, color: AppPalette.navy),
        backgroundColor: AppPalette.surfaceMuted,
        side: const BorderSide(color: AppPalette.outlineSoft),
        label: SortLabel(label: label(field), direction: direction),
      ),
    );
  }
}

/// "Date added" plus an arrow icon. An icon, not a '↑'/'↓' character: the
/// bundled text font has no arrow glyphs, so Flutter Web drew an empty box
/// until (or unless) a fallback font was downloaded.
class SortLabel extends StatelessWidget {
  const SortLabel({super.key, required this.label, required this.direction});

  final String label;
  final SortDirection direction;

  @override
  Widget build(BuildContext context) {
    final ascending = direction == SortDirection.ascending;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: AppSpacing.xs),
        Icon(
          ascending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 16,
          semanticLabel: ascending ? 'ascending' : 'descending',
        ),
      ],
    );
  }
}
