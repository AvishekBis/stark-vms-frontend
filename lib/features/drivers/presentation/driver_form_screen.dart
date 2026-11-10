import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/date_form_field.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/stale_version_dialog.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/driver.dart';
import 'driver_form_controller.dart';
import 'driver_providers.dart';

/// Add and edit a driver in one form (FR-DR01).
class DriverFormScreen extends ConsumerWidget {
  const DriverFormScreen({super.key, this.driverId});

  /// `null` adds a new driver; otherwise the driver to edit.
  final int? driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = driverId;
    if (id == null) {
      return const Scaffold(body: _DriverFormView(initial: null));
    }
    return Scaffold(
      body: AsyncValueView<Driver>(
        value: ref.watch(driverDetailProvider(id)),
        onRetry: () => ref.invalidate(driverDetailProvider(id)),
        loadingMessage: 'Loading driver…',
        // Keyed by version too, so a reload refills the form.
        data: (driver) => _DriverFormView(
          key: ValueKey((driver.id, driver.version)),
          initial: driver,
        ),
      ),
    );
  }
}

class _DriverFormView extends ConsumerStatefulWidget {
  const _DriverFormView({super.key, required this.initial});

  final Driver? initial;

  @override
  ConsumerState<_DriverFormView> createState() => _DriverFormViewState();
}

class _DriverFormViewState extends ConsumerState<_DriverFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _license;
  DateTime? _licenseExpiry;
  late DriverStatus _status;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final driver = widget.initial;
    _name = TextEditingController(text: driver?.fullName ?? '');
    _phone = TextEditingController(text: driver?.phone ?? '');
    _license = TextEditingController(text: driver?.licenseNumber ?? '');
    _licenseExpiry = driver?.licenseExpiry;
    _status = driver?.status ?? DriverStatus.active;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _license.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final controller = ref.read(driverFormControllerProvider.notifier);
    final saved = await controller.submit(
      existing: widget.initial,
      input: DriverInput(
        fullName: _name.text,
        phone: _phone.text,
        licenseNumber: _license.text,
        licenseExpiry: _licenseExpiry!,
        status: _status,
      ),
    );
    if (!mounted) {
      return;
    }
    if (saved != null) {
      AppFeedback.success(
        context,
        _isEdit
            ? 'Driver ${saved.fullName} updated.'
            : 'Driver ${saved.fullName} added.',
      );
      context.go(AppRoutes.driverDetail(saved.id));
      return;
    }
    final failure = ref.read(driverFormControllerProvider);
    final staleMessage = failure.staleVersionMessage;
    if (staleMessage != null) {
      controller.clearStaleVersion();
      await _offerReload(staleMessage);
      return;
    }
    final message = failure.errorMessage;
    if (message != null) {
      AppFeedback.error(context, message);
      controller.clearErrorMessage();
    }
  }

  /// 409 stale-version (ADR 0023): Reload refetches the driver and rebuilds
  /// the form from it; Cancel keeps the edits.
  Future<void> _offerReload(String message) async {
    final initial = widget.initial;
    final reload = await StaleVersionDialog.show(context, message: message);
    if (!reload || !mounted || initial == null) {
      return;
    }
    AppFeedback.success(context, StaleVersionDialog.reloadedMessage);
    ref.invalidate(driverDetailProvider(initial.id));
  }

  void _cancel() {
    final initial = widget.initial;
    context.go(
      initial == null ? AppRoutes.drivers : AppRoutes.driverDetail(initial.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(driverFormControllerProvider);
    final controller = ref.read(driverFormControllerProvider.notifier);
    final today = ref.watch(clockProvider).now();
    final deactivating = widget.initial?.losesVehicleOn(_status) ?? false;
    final isCompact =
        ScreenSize.fromWidth(MediaQuery.sizeOf(context).width) ==
        ScreenSize.compact;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: _isEdit ? 'Edit driver' : 'Add driver',
                subtitle: 'Fields marked * are required.',
                icon: Icons.badge_outlined,
                dense: isCompact,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                decoration: AppDecorations.card(),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autovalidateMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading(
                          title: 'Identity',
                          icon: Icons.person_outline,
                          rule: false,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          key: const Key('driverForm.fullName'),
                          controller: _name,
                          autofocus: !_isEdit,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Full name *',
                            errorText: formState.errorFor('fullName'),
                          ),
                          validator: DriverValidators.fullName,
                          onChanged: (_) =>
                              controller.clearFieldError('fullName'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          key: const Key('driverForm.phone'),
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Phone *',
                            hintText: 'e.g. 01711-000001',
                            helperText:
                                'Bangladeshi mobile number (11 digits).',
                            errorText: formState.errorFor('phone'),
                            errorMaxLines: 2,
                          ),
                          validator: DriverValidators.phone,
                          onChanged: (_) => controller.clearFieldError('phone'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const SectionHeading(
                          title: 'Licence',
                          icon: Icons.card_membership_outlined,
                          rule: false,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          key: const Key('driverForm.licenseNumber'),
                          controller: _license,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Licence number *',
                            hintText: 'e.g. DK0123456L00001',
                            errorText: formState.errorFor('licenseNumber'),
                            errorMaxLines: 2,
                          ),
                          validator: DriverValidators.licenseNumber,
                          onChanged: (_) =>
                              controller.clearFieldError('licenseNumber'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DateFormField(
                          key: const Key('driverForm.licenseExpiry'),
                          label: 'Licence expiry *',
                          initialValue: _licenseExpiry,
                          firstDate: DateTime(today.year - 30),
                          lastDate: DateTime(today.year + 30),
                          helperText:
                              'A past date is allowed; it shows as Expired.',
                          errorText: formState.errorFor('licenseExpiry'),
                          validator: DriverValidators.licenseExpiry,
                          onChanged: (value) {
                            _licenseExpiry = value;
                            controller.clearFieldError('licenseExpiry');
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<DriverStatus>(
                          key: const Key('driverForm.status'),
                          initialValue: _status,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            errorText: formState.errorFor('status'),
                            helperText: deactivating
                                ? 'Saving as Inactive unassigns the driver from '
                                      '${widget.initial!.currentVehicle!.vehicleNumber}.'
                                : null,
                            helperMaxLines: 2,
                          ),
                          items: [
                            for (final status in DriverStatus.values)
                              DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _status = value);
                              controller.clearFieldError('status');
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            OutlinedButton(
                              key: const Key('driverForm.cancel'),
                              onPressed: formState.isSubmitting
                                  ? null
                                  : _cancel,
                              child: const Text('Cancel'),
                            ),
                            FilledButton.icon(
                              key: const Key('driverForm.save'),
                              onPressed: formState.isSubmitting
                                  ? null
                                  : _submit,
                              icon: formState.isSubmitting
                                  ? const SizedBox.square(
                                      dimension: AppSpacing.md,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _isEdit ? 'Save changes' : 'Add driver',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
