import 'package:flutter/material.dart';

import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_palette.dart';

/// The frame every list table uses on medium and wide screens: a card at
/// least as wide as the space it gets, which scrolls sideways when the
/// columns need more room and (unless [scrollVertically] is `false`
/// because it already sits in a scroll view) up and down.
///
/// The card is the shared surface from [AppDecorations.card], so a table sits
/// on the same white-on-cream, hairline-and-soft-shadow panel as every other
/// block on the page.
class DataTableFrame extends StatelessWidget {
  const DataTableFrame({
    super.key,
    required this.table,
    this.scrollVertically = true,
  });

  final Widget table;
  final bool scrollVertically;

  /// The row colour every list table shares: a hairline zebra on every second
  /// row and a gold veil under the pointer, so the eye keeps its place across
  /// a wide table. One definition, so the tables cannot drift apart.
  static WidgetStateProperty<Color?> zebraRow(int index) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return AppPalette.goldTint;
      }
      return index.isOdd ? AppPalette.surfaceMuted : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final framed = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: AppDecorations.card(),
              child: table,
            ),
          ),
        );
        return scrollVertically ? SingleChildScrollView(child: framed) : framed;
      },
    );
  }
}

/// Text in a table cell that is cut off with "…" beyond [maxWidth], so one
/// long value (notes, a vendor name) cannot stretch the whole table.
class TableCellText extends StatelessWidget {
  const TableCellText(this.text, {super.key, this.maxWidth = 240, this.style});

  final String text;
  final double maxWidth;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
