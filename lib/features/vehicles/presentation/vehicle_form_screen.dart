import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/feedback.dart';
import '../../../shared/widgets/stale_version_dialog.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/vehicle.dart';
import '../data/vehicle_enums.dart';
import 'vehicle_form_controller.dart';
import 'vehicle_providers.dart';

/// Register (FR-V02) and edit (FR-V03) a vehicle in one screen.
class VehicleFormScreen extends ConsumerWidget {
  const VehicleFormScreen({super.key, this.vehicleId});

  /// `null` registers a new vehicle; otherwise the vehicle to edit.
  final int? vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = vehicleId;
    if (id == null) {
      return const Scaffold(body: _VehicleFormView(initial: null));
    }
    return Scaffold(
      body: AsyncValueView<Vehicle>(
        value: ref.watch(vehicleDetailProvider(id)),
        onRetry: () => ref.invalidate(vehicleDetailProvider(id)),
        loadingMessage: 'Loading vehicle…',
        // Keyed by version too: a reload after 409 stale-version refills
        // the form from the fresh record.
        data: (vehicle) => _VehicleFormView(
          key: ValueKey((vehicle.id, vehicle.version)),
          initial: vehicle,
        ),
      ),
    );
  }
}

class _VehicleFormView extends ConsumerStatefulWidget {
  const _VehicleFormView({super.key, required this.initial});

  final Vehicle? initial;

  @override
  ConsumerState<_VehicleFormView> createState() => _VehicleFormViewState();
}

class _VehicleFormViewState extends ConsumerState<_VehicleFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _color;
  VehicleType? _type;
  FuelType? _fuel;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.initial;
    _number = TextEditingController(text: vehicle?.vehicleNumber ?? '');
    _brand = TextEditingController(text: vehicle?.brand ?? '');
    _model = TextEditingController(text: vehicle?.model ?? '');
    _year = TextEditingController(
      text: vehicle?.manufactureYear?.toString() ?? '',
    );
    _color = TextEditingController(text: vehicle?.color ?? '');
    _type = vehicle?.vehicleType;
    _fuel = vehicle?.fuelType;
  }

  @override
  void dispose() {
    _number.dispose();
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _color.dispose();
    super.dispose();
  }

  VehicleInput _buildInput() {
    return VehicleInput(
      vehicleNumber: _number.text,
      vehicleType: _type!,
      brand: _brand.text,
      model: _model.text,
      manufactureYear: int.tryParse(_year.text.trim()),
      color: _color.text,
      fuelType: _fuel,
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final controller = ref.read(vehicleFormControllerProvider.notifier);
    final saved = await controller.submit(
      existing: widget.initial,
      input: _buildInput(),
    );
    if (!mounted) {
      return;
    }
    if (saved != null) {
      AppFeedback.success(
        context,
        _isEdit
            ? 'Vehicle ${saved.vehicleNumber} updated.'
            : 'Vehicle ${saved.vehicleNumber} registered.',
      );
      context.go(AppRoutes.vehicleDetail(saved.id));
      return;
    }
    final failure = ref.read(vehicleFormControllerProvider);
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

  /// 409 stale-version (ADR 0023): Reload refetches the vehicle, which
  /// rebuilds this form with the fresh values; Cancel keeps the edits.
  Future<void> _offerReload(String message) async {
    final initial = widget.initial;
    final reload = await StaleVersionDialog.show(context, message: message);
    if (!reload || !mounted || initial == null) {
      return;
    }
    AppFeedback.success(context, StaleVersionDialog.reloadedMessage);
    ref.invalidate(vehicleDetailProvider(initial.id));
  }

  void _cancel() {
    final initial = widget.initial;
    context.go(
      initial == null
          ? AppRoutes.vehicles
          : AppRoutes.vehicleDetail(initial.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(vehicleFormControllerProvider);
    final controller = ref.read(vehicleFormControllerProvider.notifier);
    final currentYear = ref.watch(clockProvider).now().year;
    final isCompact =
        ScreenSize.fromWidth(MediaQuery.sizeOf(context).width) ==
        ScreenSize.compact;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.formMaxWidth),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: _isEdit ? 'Edit vehicle' : 'Register vehicle',
                  subtitle: 'Fields marked * are required.',
                  icon: _isEdit ? Icons.edit_outlined : Icons.directions_car,
                  dense: isCompact,
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: AppDecorations.card(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeading(
                              title: 'Identification',
                              icon: Icons.confirmation_number_outlined,
                              rule: false,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              key: const Key('vehicleForm.number'),
                              controller: _number,
                              autofocus: !_isEdit,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Vehicle number *',
                                hintText: 'e.g. DHAKA METRO-GA 11-2345',
                                errorText: formState.errorFor('vehicleNumber'),
                                errorMaxLines: 2,
                              ),
                              validator: VehicleValidators.vehicleNumber,
                              onChanged: (_) =>
                                  controller.clearFieldError('vehicleNumber'),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _ResponsivePair(
                              first: DropdownButtonFormField<VehicleType>(
                                key: const Key('vehicleForm.type'),
                                initialValue: _type,
                                decoration: InputDecoration(
                                  labelText: 'Vehicle type *',
                                  errorText: formState.errorFor('vehicleType'),
                                ),
                                items: [
                                  for (final type in VehicleType.values)
                                    DropdownMenuItem(
                                      value: type,
                                      child: Text(type.label),
                                    ),
                                ],
                                validator: (value) => value == null
                                    ? 'Vehicle type is required.'
                                    : null,
                                onChanged: (value) {
                                  setState(() => _type = value);
                                  controller.clearFieldError('vehicleType');
                                },
                              ),
                              second: DropdownButtonFormField<FuelType?>(
                                key: const Key('vehicleForm.fuel'),
                                initialValue: _fuel,
                                decoration: InputDecoration(
                                  labelText: 'Fuel type',
                                  errorText: formState.errorFor('fuelType'),
                                ),
                                items: [
                                  const DropdownMenuItem<FuelType?>(
                                    child: Text('Not specified'),
                                  ),
                                  for (final fuel in FuelType.values)
                                    DropdownMenuItem<FuelType?>(
                                      value: fuel,
                                      child: Text(fuel.label),
                                    ),
                                ],
                                onChanged: (value) {
                                  setState(() => _fuel = value);
                                  controller.clearFieldError('fuelType');
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const SectionHeading(
                              title: 'Specification',
                              icon: Icons.tune,
                              rule: false,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _ResponsivePair(
                              first: TextFormField(
                                key: const Key('vehicleForm.brand'),
                                controller: _brand,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Brand',
                                  hintText: 'e.g. Toyota',
                                  errorText: formState.errorFor('brand'),
                                ),
                                validator: VehicleValidators.brand,
                                onChanged: (_) =>
                                    controller.clearFieldError('brand'),
                              ),
                              second: TextFormField(
                                key: const Key('vehicleForm.model'),
                                controller: _model,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Model',
                                  hintText: 'e.g. Axio',
                                  errorText: formState.errorFor('model'),
                                ),
                                validator: VehicleValidators.model,
                                onChanged: (_) =>
                                    controller.clearFieldError('model'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _ResponsivePair(
                              first: TextFormField(
                                key: const Key('vehicleForm.year'),
                                controller: _year,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Manufacture year',
                                  hintText:
                                      '${VehicleValidators.minManufactureYear}–${currentYear + 1}',
                                  errorText: formState.errorFor(
                                    'manufactureYear',
                                  ),
                                ),
                                validator: (value) =>
                                    VehicleValidators.manufactureYear(
                                      value,
                                      currentYear: currentYear,
                                    ),
                                onChanged: (_) => controller.clearFieldError(
                                  'manufactureYear',
                                ),
                              ),
                              second: TextFormField(
                                key: const Key('vehicleForm.color'),
                                controller: _color,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Colour',
                                  hintText: 'e.g. White',
                                  errorText: formState.errorFor('color'),
                                ),
                                validator: VehicleValidators.color,
                                onChanged: (_) =>
                                    controller.clearFieldError('color'),
                                onFieldSubmitted: (_) => _submit(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // The action row reads as a footer rail: its own warm band,
                      // closed off by a hairline, so Save always looks anchored to
                      // the bottom of the form.
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppPalette.surfaceMuted,
                          border: Border(
                            top: BorderSide(color: AppPalette.outlineSoft),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              OutlinedButton(
                                key: const Key('vehicleForm.cancel'),
                                onPressed: formState.isSubmitting
                                    ? null
                                    : _cancel,
                                child: const Text('Cancel'),
                              ),
                              FilledButton.icon(
                                key: const Key('vehicleForm.save'),
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
                                  _isEdit ? 'Save changes' : 'Register vehicle',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two fields side by side on wide screens, stacked on narrow ones.
class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < ScreenSize.mediumMinWidth - AppSpacing.xl) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: AppSpacing.md),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
