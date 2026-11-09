import 'package:flutter/material.dart';

/// The frame every list table uses on medium and wide screens: a card at
/// least as wide as the space it gets, which scrolls sideways when the
/// columns need more room and (unless [scrollVertically] is `false`
/// because it already sits in a scroll view) up and down.
class DataTableFrame extends StatelessWidget {
  const DataTableFrame({
    super.key,
    required this.table,
    this.scrollVertically = true,
  });

  final Widget table;
  final bool scrollVertically;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final framed = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Card(clipBehavior: Clip.antiAlias, child: table),
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
