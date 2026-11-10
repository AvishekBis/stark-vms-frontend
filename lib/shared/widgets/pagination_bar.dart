import 'package:flutter/material.dart';

import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';

/// "Page x of y · N items" with previous / next and a page-size picker, on a
/// warm muted strip with a gold hairline, so it reads as the footer of the
/// list above it.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.totalElements,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.itemLabel = 'items',
  });

  /// Zero-based current page.
  final int page;
  final int totalPages;
  final int totalElements;
  final int pageSize;

  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final String itemLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pageCount = totalPages < 1 ? 1 : totalPages;
    final hasPrevious = page > 0;
    final hasNext = page + 1 < totalPages;
    return Padding(
      // The strip is height- and width-neutral: the 2 px gold edge is taken
      // back off the top padding, so a 360 px phone keeps the same layout.
      padding: const EdgeInsets.only(
        top: AppSpacing.sm - 2,
        bottom: AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppDecorations.radius),
          border: const Border(
            top: BorderSide(color: AppPalette.goldSoft, width: 2),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Text(
              '${Formatters.count(totalElements)} $itemLabel',
              key: const Key('pagination.total'),
              style: textTheme.titleSmall,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rows per page', style: textTheme.bodyMedium),
                const SizedBox(width: AppSpacing.sm),
                DropdownButton<int>(
                  key: const Key('pagination.size'),
                  value: pageSizeOptions.contains(pageSize) ? pageSize : null,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final option in pageSizeOptions)
                      DropdownMenuItem<int>(
                        value: option,
                        child: Text('$option'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null && value != pageSize) {
                      onPageSizeChanged(value);
                    }
                  },
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('pagination.previous'),
                  tooltip: 'Previous page',
                  onPressed: hasPrevious ? () => onPageChanged(page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                  color: AppPalette.navy,
                ),
                Text(
                  'Page ${page + 1} of $pageCount',
                  key: const Key('pagination.label'),
                  style: textTheme.bodyMedium,
                ),
                IconButton(
                  key: const Key('pagination.next'),
                  tooltip: 'Next page',
                  onPressed: hasNext ? () => onPageChanged(page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                  color: AppPalette.navy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
