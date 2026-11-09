import 'package:flutter/material.dart';

/// One choice of a [FilterMenu]; `value == null` means "all".
class _FilterChoice<T> {
  const _FilterChoice(this.value);

  final T? value;
}

/// A chip that opens a menu of filter values ("Status: All" →
/// "Status: Maintenance"). The menu items are only built when it opens.
class FilterMenu<T> extends StatelessWidget {
  const FilterMenu({
    super.key,
    required this.label,
    required this.options,
    required this.optionLabel,
    required this.selected,
    required this.onChanged,
    this.allLabel = 'All',
  });

  final String label;
  final List<T> options;
  final String Function(T option) optionLabel;
  final T? selected;
  final ValueChanged<T?> onChanged;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    final isFiltered = current != null;
    return PopupMenuButton<_FilterChoice<T>>(
      tooltip: 'Filter by ${label.toLowerCase()}',
      onSelected: (choice) => onChanged(choice.value),
      itemBuilder: (context) => [
        CheckedPopupMenuItem<_FilterChoice<T>>(
          value: _FilterChoice<T>(null),
          checked: !isFiltered,
          child: Text(allLabel),
        ),
        for (final option in options)
          CheckedPopupMenuItem<_FilterChoice<T>>(
            value: _FilterChoice<T>(option),
            checked: option == current,
            child: Text(optionLabel(option)),
          ),
      ],
      child: Chip(
        avatar: Icon(isFiltered ? Icons.filter_alt : Icons.filter_alt_outlined),
        label: Text(
          '$label: ${current != null ? optionLabel(current) : allLabel}',
        ),
      ),
    );
  }
}
