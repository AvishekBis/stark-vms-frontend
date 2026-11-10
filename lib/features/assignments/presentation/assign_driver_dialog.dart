import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/page_response.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/debouncer.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/state_views.dart';
import '../../drivers/data/driver.dart';
import '../../drivers/data/driver_query.dart';
import '../../drivers/presentation/widgets/driver_widgets.dart';
import '../../vehicles/data/vehicle.dart';
import 'assignment_providers.dart';

/// Opens the assign / change driver dialog (FR-DR02). Resolves to `true`
/// when a driver was assigned.
Future<bool> showAssignDriverDialog(
  BuildContext context, {
  required Vehicle vehicle,
}) async {
  final assigned = await showDialog<bool>(
    context: context,
    builder: (_) => AssignDriverDialog(vehicle: vehicle),
  );
  return assigned ?? false;
}

/// Searchable list of available drivers. A rejected assignment (409
/// `driver-already-assigned`, TC-10, or `assignment-not-allowed`) is shown
/// inside the dialog with the server's explanation.
class AssignDriverDialog extends ConsumerStatefulWidget {
  const AssignDriverDialog({super.key, required this.vehicle});

  final Vehicle vehicle;

  static const int listSize = 20;

  @override
  ConsumerState<AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends ConsumerState<AssignDriverDialog> {
  final TextEditingController _search = TextEditingController();
  final Debouncer _debouncer = Debouncer(delay: AppConfig.searchDebounce);
  String _searchText = '';
  bool _includeAssigned = false;
  Driver? _selected;
  bool _submitting = false;
  ApiException? _error;

  DriverQuery get _query => DriverQuery(
    size: AssignDriverDialog.listSize,
    search: _searchText,
    status: DriverStatus.active,
    available: _includeAssigned ? null : true,
  );

  @override
  void dispose() {
    _debouncer.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    final driver = _selected;
    if (driver == null || _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(assignmentActionsProvider)
          .assign(vehicleId: widget.vehicle.id, driverId: driver.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = widget.vehicle.currentDriver;
    final drivers = ref.watch(assignableDriversProvider(_query));
    final error = _error;

    return AlertDialog(
      key: const Key('assignDialog'),
      scrollable: true,
      title: DialogTitle(
        icon: Icons.person_add_alt_1_outlined,
        title: current == null
            ? 'Assign a driver to ${widget.vehicle.vehicleNumber}'
            : 'Change the driver of ${widget.vehicle.vehicleNumber}',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.dialogMaxWidth),
        child: SizedBox(
          width: AppSpacing.dialogMaxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (current != null) ...[
                // A note, not a warning: a gold veil and a plate, no tone.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppPalette.goldTint,
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(
                      AppSpacing.sm + AppSpacing.xs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const IconPlate(
                          icon: Icons.swap_horiz,
                          tint: AppPalette.goldSoft,
                          size: 32,
                        ),
                        const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Current driver: ${current.fullName}. Assigning someone '
                            'else ends that assignment (history is kept).',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(
                key: const Key('assignDialog.search'),
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search name, phone or licence',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) => _debouncer.run(
                  () => setState(() {
                    _searchText = value.trim();
                    _selected = null;
                  }),
                ),
              ),
              CheckboxListTile(
                key: const Key('assignDialog.includeAssigned'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _includeAssigned,
                title: const Text(
                  'Also show drivers assigned to other vehicles',
                ),
                onChanged: (value) => setState(() {
                  _includeAssigned = value ?? false;
                  _selected = null;
                }),
              ),
              SizedBox(
                height: AppSpacing.dialogListHeight,
                child: AsyncValueView<PageResponse<Driver>>(
                  value: drivers,
                  onRetry: () =>
                      ref.invalidate(assignableDriversProvider(_query)),
                  isEmpty: (page) => page.isEmpty,
                  empty: EmptyView(
                    icon: Icons.person_search_outlined,
                    title: _searchText.isEmpty
                        ? 'No available drivers'
                        : 'No drivers match "$_searchText"',
                    message: 'Only ACTIVE drivers without a vehicle can be assigned.',
                  ),
                  data: (page) => ListView(
                    children: [
                      if (page.totalElements > page.content.length)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            'Showing ${page.content.length} of '
                            '${page.totalElements} drivers - search to narrow '
                            'the list.',
                            key: const Key('assignDialog.moreHint'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      for (final driver in page.content)
                        _DriverChoice(
                          driver: driver,
                          isCurrent: driver.id == current?.id,
                          selected: driver.id == _selected?.id,
                          onTap: () => setState(() {
                            _selected = driver;
                            _error = null;
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _ErrorBox(error: error),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('assignDialog.cancel'),
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('assignDialog.assign'),
          onPressed: _selected == null || _submitting ? null : _assign,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: AppSpacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt),
          label: const Text('Assign'),
        ),
      ],
    );
  }
}

class _DriverChoice extends StatelessWidget {
  const _DriverChoice({
    required this.driver,
    required this.isCurrent,
    required this.selected,
    required this.onTap,
  });

  final Driver driver;
  final bool isCurrent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vehicle = driver.currentVehicle;
    final details = [
      driver.phone,
      if (isCurrent) 'current driver',
      if (!isCurrent && vehicle != null) 'drives ${vehicle.vehicleNumber}',
    ].join(' · ');
    // The chosen row is marked three ways — the radio glyph, the gold veil and
    // the gold edge — so it never relies on colour alone.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        key: ValueKey('assignDialog.driver.${driver.id}'),
        selected: selected,
        selectedColor: AppPalette.navy,
        selectedTileColor: AppPalette.goldTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDecorations.radius),
          side: BorderSide(
            color: selected ? AppPalette.gold : AppPalette.outlineSoft,
          ),
        ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppPalette.navy : AppPalette.inkMuted,
            ),
            const SizedBox(width: AppSpacing.sm),
            InitialsAvatar(
              name: driver.fullName,
              size: 36,
              tint: selected ? AppPalette.goldSoft : AppPalette.surfaceMuted,
            ),
          ],
        ),
        title: Text(driver.fullName),
        subtitle: Text(details),
        trailing: LicenseExpiryBadge(driver: driver),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error});

  final ApiException error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = StatusColors.of(context).danger;
    final title = error.title;
    return DecoratedBox(
      key: const Key('assignDialog.error'),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        border: Border.all(color: danger.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconPlate(
              icon: Icons.error_outline,
              tint: danger.withValues(alpha: 0.14),
              color: danger,
              size: 34,
            ),
            const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: danger,
                      ),
                    ),
                  Text(
                    error.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppPalette.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
