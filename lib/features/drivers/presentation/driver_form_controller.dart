import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/form_errors.dart';
import '../../../core/utils/change_tracker.dart';
import '../data/driver.dart';
import '../data/driver_repository.dart';

/// Saves a driver (FR-DR01) and puts server errors under the right field:
/// 409 duplicate phone → `phone`, duplicate licence → `licenseNumber`.
class DriverFormController extends AutoDisposeNotifier<FormSubmitState> {
  static const Map<String, String> duplicateTypes = {
    'duplicate-driver-phone': 'phone',
    'duplicate-driver-license': 'licenseNumber',
  };

  @override
  FormSubmitState build() => const FormSubmitState();

  /// Creates when [existing] is `null`, otherwise updates it with the
  /// `version` it was loaded with. Returns the saved driver, or `null` when
  /// the server rejected it (see [state]; 409 `stale-version` sets
  /// [FormSubmitState.isStale]).
  Future<Driver?> submit({Driver? existing, required DriverInput input}) async {
    if (state.isSubmitting) {
      return null;
    }
    state = const FormSubmitState(isSubmitting: true);
    final repository = ref.read(driverRepositoryProvider);
    try {
      final saved = existing == null
          ? await repository.create(input)
          : await repository.update(
              existing.id,
              input,
              version: existing.version,
            );
      ref.read(driverChangesProvider.notifier).markChanged();
      // An INACTIVE driver loses the current vehicle on the server.
      ref.read(vehicleChangesProvider.notifier).markChanged();
      state = const FormSubmitState();
      return saved;
    } on ApiException catch (error) {
      state = FormSubmitState.failed(
        error,
        fields: DriverInput.fieldNames,
        typeToField: duplicateTypes,
      );
      return null;
    }
  }

  void clearFieldError(String field) {
    final errors = state.errors.withoutField(field);
    if (!identical(errors, state.errors)) {
      state = FormSubmitState(isSubmitting: state.isSubmitting, errors: errors);
    }
  }

  void clearStaleVersion() {
    if (state.isStale) {
      state = state.withoutStaleVersion();
    }
  }

  void clearErrorMessage() {
    if (state.errorMessage != null) {
      state = FormSubmitState(
        isSubmitting: state.isSubmitting,
        errors: state.errors.withoutMessage(),
      );
    }
  }
}

final driverFormControllerProvider =
    NotifierProvider.autoDispose<DriverFormController, FormSubmitState>(
      DriverFormController.new,
    );
