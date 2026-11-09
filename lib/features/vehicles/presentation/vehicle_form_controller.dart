import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/form_errors.dart';
import '../../../core/utils/change_tracker.dart';
import '../data/vehicle.dart';
import '../data/vehicle_repository.dart';
import 'vehicle_providers.dart';

/// Saves a vehicle (FR-V02 create, FR-V03 update) and maps server errors
/// (400 validation, 409 duplicate number, FR-V05) onto the form fields.
/// A 409 `stale-version` (ADR 0023) becomes [FormSubmitState.isStale].
class VehicleFormController extends AutoDisposeNotifier<FormSubmitState> {
  static const Map<String, String> duplicateTypes = {
    'duplicate-vehicle-number': 'vehicleNumber',
  };

  @override
  FormSubmitState build() => const FormSubmitState();

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
    state = const FormSubmitState(isSubmitting: true);
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
      state = const FormSubmitState();
      return saved;
    } on ApiException catch (error) {
      state = FormSubmitState.failed(
        error,
        fields: VehicleInput.fieldNames,
        typeToField: duplicateTypes,
      );
      return null;
    }
  }

  /// Removes a server error once the user edits that field.
  void clearFieldError(String field) {
    final errors = state.errors.withoutField(field);
    if (!identical(errors, state.errors)) {
      state = FormSubmitState(isSubmitting: state.isSubmitting, errors: errors);
    }
  }

  /// Clears the stale-version flag once the dialog has been shown.
  void clearStaleVersion() {
    if (state.isStale) {
      state = state.withoutStaleVersion();
    }
  }

  /// Clears the non-field message after it has been shown.
  void clearErrorMessage() {
    if (state.errorMessage != null) {
      state = FormSubmitState(
        isSubmitting: state.isSubmitting,
        errors: state.errors.withoutMessage(),
      );
    }
  }
}

final vehicleFormControllerProvider =
    NotifierProvider.autoDispose<VehicleFormController, FormSubmitState>(
      VehicleFormController.new,
    );
