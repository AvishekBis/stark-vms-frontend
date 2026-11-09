import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/form_errors.dart';
import '../../../core/utils/change_tracker.dart';
import '../data/maintenance_record.dart';
import '../data/maintenance_repository.dart';

/// Bumped after every maintenance create / update / delete.
final maintenanceChangesProvider = NotifierProvider<ChangeTracker, int>(
  ChangeTracker.new,
);

/// One page of a vehicle's maintenance history with the total cost.
final maintenanceHistoryProvider = FutureProvider.autoDispose
    .family<MaintenanceHistory, ({int vehicleId, int page})>((ref, key) {
      ref.watch(maintenanceChangesProvider);
      return ref
          .watch(maintenanceRepositoryProvider)
          .history(key.vehicleId, page: key.page);
    });

/// Saves a record (create when `existing` is `null`) and maps server
/// errors onto the form fields; 409 `stale-version` sets
/// [FormSubmitState.isStale].
class MaintenanceFormController extends AutoDisposeNotifier<FormSubmitState> {
  @override
  FormSubmitState build() => const FormSubmitState();

  Future<MaintenanceRecord?> submit({
    required int vehicleId,
    MaintenanceRecord? existing,
    required MaintenanceInput input,
  }) async {
    if (state.isSubmitting) {
      return null;
    }
    state = const FormSubmitState(isSubmitting: true);
    final repository = ref.read(maintenanceRepositoryProvider);
    try {
      final saved = existing == null
          ? await repository.create(vehicleId, input)
          : await repository.update(
              existing.id,
              input,
              version: existing.version,
            );
      ref.read(maintenanceChangesProvider.notifier).markChanged();
      state = const FormSubmitState();
      return saved;
    } on ApiException catch (error) {
      state = FormSubmitState.failed(
        error,
        fields: MaintenanceInput.fieldNames,
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

  /// "Reload" after 409 stale-version: the record as the server has it now.
  /// The history is refreshed too, since it shows the old values.
  Future<MaintenanceRecord> reload(int recordId) async {
    final fresh = await ref.read(maintenanceRepositoryProvider).get(recordId);
    ref.read(maintenanceChangesProvider.notifier).markChanged();
    state = const FormSubmitState();
    return fresh;
  }
}

final maintenanceFormControllerProvider =
    NotifierProvider.autoDispose<MaintenanceFormController, FormSubmitState>(
      MaintenanceFormController.new,
    );

/// Delete (ADMIN).
class MaintenanceActions {
  const MaintenanceActions(this._ref);

  final Ref<Object?> _ref;

  Future<void> delete(MaintenanceRecord record) async {
    await _ref.read(maintenanceRepositoryProvider).delete(record.id);
    _ref.read(maintenanceChangesProvider.notifier).markChanged();
  }

  static String deleteErrorMessage(Object error) {
    if (error is ApiException) {
      return error.isForbidden
          ? 'Only an administrator can delete maintenance records.'
          : error.message;
    }
    return 'The record could not be deleted. Please try again.';
  }
}

final maintenanceActionsProvider = Provider<MaintenanceActions>(
  (ref) => MaintenanceActions(ref),
);
