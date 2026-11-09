import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/vehicle.dart';
import '../data/vehicle_repository.dart';
import 'vehicle_providers.dart';

/// Submission state of the vehicle form.
class VehicleFormState {
  const VehicleFormState({
    this.isSubmitting = false,
    this.fieldErrors = const {},
    this.errorMessage,
    this.staleVersionMessage,
  });

  final bool isSubmitting;

  /// Server errors keyed by request field name (e.g. `vehicleNumber`).
  final Map<String, String> fieldErrors;

  /// A server error that does not belong to a single field.
  final String? errorMessage;

  /// The server `detail` of a 409 `stale-version` (ADR 0023), kept apart so
  /// the screen offers "Reload" instead of showing it like any other error.
  /// Cleared once the dialog has been shown.
  final String? staleVersionMessage;

  bool get isStale => staleVersionMessage != null;

  String? errorFor(String field) => fieldErrors[field];
}

/// Saves a vehicle (FR-V02 create, FR-V03 update) and maps server errors
/// (400 validation, 409 duplicate number, FR-V05) onto the form fields.
/// A 409 `stale-version` (ADR 0023) becomes [VehicleFormState.isStale].
class VehicleFormController extends AutoDisposeNotifier<VehicleFormState> {
  static const String _duplicateNumberType = 'duplicate-vehicle-number';

  @override
  VehicleFormState build() => const VehicleFormState();

  /// Creates when [existing] is `null`, otherwise updates it, sending the
  /// `version` it was loaded with. Returns the saved vehicle, or `null` when
  /// the server rejected it (see [state]).
  Future<Vehicle?> submit({
    Vehicle? existing,
    required VehicleInput input,
  }) async {
    if (state.isSubmitting) {
      return null;
    }
    state = const VehicleFormState(isSubmitting: true);
    final repository = ref.read(vehicleRepositoryProvider);
    try {
      final saved = existing == null
          ? await repository.create(input)
          : await repository.update(
              existing.id,
              input,
              version: existing.version,
            );
      ref.read(vehicleChangesProvider.notifier).markChanged();
      ref.invalidate(vehicleDetailProvider(saved.id));
      state = const VehicleFormState();
      return saved;
    } on ApiException catch (error) {
      if (error.isStaleVersion) {
        state = VehicleFormState(staleVersionMessage: error.message);
        return null;
      }
      final fieldErrors = _fieldErrorsFor(error);
      state = VehicleFormState(
        fieldErrors: fieldErrors,
        errorMessage: fieldErrors.isEmpty
            ? error.message
            : _unmappedFieldMessage(error),
      );
      return null;
    }
  }

  /// Removes a server error once the user edits that field.
  void clearFieldError(String field) {
    if (!state.fieldErrors.containsKey(field)) {
      return;
    }
    final remaining = Map<String, String>.of(state.fieldErrors)..remove(field);
    state = VehicleFormState(
      fieldErrors: remaining,
      isSubmitting: state.isSubmitting,
    );
  }

  /// Clears the stale-version flag once the dialog has been shown.
  void clearStaleVersion() {
    if (state.isStale) {
      state = VehicleFormState(
        fieldErrors: state.fieldErrors,
        isSubmitting: state.isSubmitting,
      );
    }
  }

  /// Clears the non-field message after it has been shown.
  void clearErrorMessage() {
    if (state.errorMessage != null) {
      state = VehicleFormState(
        fieldErrors: state.fieldErrors,
        isSubmitting: state.isSubmitting,
      );
    }
  }

  /// Server field errors that have no field on this form (so they are not
  /// lost), or `null` when every error is shown under its field.
  static String? _unmappedFieldMessage(ApiException error) {
    final unmapped = [
      for (final entry in error.fieldErrors.entries)
        if (!VehicleInput.fieldNames.contains(entry.key)) entry.value,
    ];
    return unmapped.isEmpty ? null : unmapped.join(' ');
  }

  static Map<String, String> _fieldErrorsFor(ApiException error) {
    final known = {
      for (final entry in error.fieldErrors.entries)
        if (VehicleInput.fieldNames.contains(entry.key)) entry.key: entry.value,
    };
    final isDuplicate =
        error.isConflict &&
        (error.type?.endsWith(_duplicateNumberType) ?? false);
    if (known.isEmpty && isDuplicate) {
      return {'vehicleNumber': error.message};
    }
    return known;
  }
}

final vehicleFormControllerProvider =
    NotifierProvider.autoDispose<VehicleFormController, VehicleFormState>(
      VehicleFormController.new,
    );
