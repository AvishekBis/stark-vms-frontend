import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/form_errors.dart';
import '../../../core/network/page_response.dart';
import '../../../core/platform/file_opener.dart';
import '../../../core/utils/change_tracker.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/document_repository.dart';
import '../data/vehicle_document.dart';

/// Bumped after every upload / delete; the dashboard watches it too.
final documentChangesProvider = NotifierProvider<ChangeTracker, int>(
  ChangeTracker.new,
);

/// All documents of one vehicle, soonest expiry first.
final vehicleDocumentsProvider = FutureProvider.autoDispose
    .family<List<VehicleDocument>, int>((ref, vehicleId) async {
      ref.watch(documentChangesProvider);
      final documents = await ref
          .watch(documentRepositoryProvider)
          .listForVehicle(vehicleId);
      final sorted = [...documents]
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return List<VehicleDocument>.unmodifiable(sorted);
    });

/// Parameters of the "Expiring documents" screen.
class ExpiringDocumentsQuery {
  const ExpiringDocumentsQuery({
    this.withinDays = DocumentRepository.defaultWithinDays,
    this.page = 0,
    this.size = DocumentRepository.defaultPageSize,
  });

  static const List<int> withinDaysOptions = [7, 30, 60, 90];
  static const List<int> pageSizeOptions = [10, 20, 50, 100];

  final int withinDays;
  final int page;
  final int size;

  ExpiringDocumentsQuery copyWith({int? withinDays, int? page, int? size}) {
    return ExpiringDocumentsQuery(
      withinDays: withinDays ?? this.withinDays,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExpiringDocumentsQuery &&
      other.withinDays == withinDays &&
      other.page == page &&
      other.size == size;

  @override
  int get hashCode => Object.hash(withinDays, page, size);
}

class ExpiringDocumentsQueryController
    extends Notifier<ExpiringDocumentsQuery> {
  @override
  ExpiringDocumentsQuery build() {
    ref.watch(currentUserProvider.select((user) => user?.id));
    return const ExpiringDocumentsQuery();
  }

  /// Changing the window starts again at the first page.
  void setWithinDays(int days) {
    if (days != state.withinDays) {
      state = state.copyWith(withinDays: days, page: 0);
    }
  }

  /// Used by links (dashboard "View all"): that window, first page.
  void showWithin(int days) {
    final next = state.copyWith(withinDays: days, page: 0);
    if (next != state) {
      state = next;
    }
  }

  void goToPage(int page) {
    if (page >= 0 && page != state.page) {
      state = state.copyWith(page: page);
    }
  }

  void setPageSize(int size) => state = state.copyWith(size: size, page: 0);
}

final expiringDocumentsQueryProvider =
    NotifierProvider<ExpiringDocumentsQueryController, ExpiringDocumentsQuery>(
      ExpiringDocumentsQueryController.new,
    );

/// `GET /documents/expiring` — expired and expiring documents of the fleet.
final expiringDocumentsProvider =
    FutureProvider.autoDispose<PageResponse<VehicleDocument>>((ref) {
      ref.watch(documentChangesProvider);
      final query = ref.watch(expiringDocumentsQueryProvider);
      return ref
          .watch(documentRepositoryProvider)
          .expiring(
            withinDays: query.withinDays,
            page: query.page,
            size: query.size,
          );
    });

/// View, download and delete a stored document.
class DocumentActions {
  const DocumentActions(this._ref);

  final Ref<Object?> _ref;

  /// Opens the file in a new browser tab. Call it straight from the click
  /// handler (no `await` before it) so the browser allows the new tab.
  Future<void> view(VehicleDocument document) {
    final repository = _ref.read(documentRepositoryProvider);
    return _ref
        .read(fileOpenerProvider)
        .open(
          () => repository.fetchFile(document.id),
          fileName: document.downloadName,
          contentType: document.contentType,
        );
  }

  Future<void> download(VehicleDocument document) {
    final repository = _ref.read(documentRepositoryProvider);
    return _ref
        .read(fileOpenerProvider)
        .download(
          () => repository.fetchFile(document.id, download: true),
          fileName: document.downloadName,
          contentType: document.contentType,
        );
  }

  Future<void> delete(VehicleDocument document) async {
    await _ref.read(documentRepositoryProvider).delete(document.id);
    _ref.read(documentChangesProvider.notifier).markChanged();
  }

  /// A message for a failed view / download / delete; [fallback] is used
  /// for errors that are not API errors, and [forbidden] (when given) for
  /// a 403 instead of the server's message.
  static String errorMessage(
    Object error, {
    required String fallback,
    String? forbidden,
  }) {
    if (error is ApiException) {
      if (error.isForbidden && forbidden != null) {
        return forbidden;
      }
      return error.message;
    }
    return fallback;
  }

  static const String deleteForbiddenMessage =
      'Only an administrator can delete documents.';
}

final documentActionsProvider = Provider<DocumentActions>(
  (ref) => DocumentActions(ref),
);

/// Uploads a document and maps 400 `errors[]` and 413 onto the fields.
class DocumentUploadController extends AutoDisposeNotifier<FormSubmitState> {
  @override
  FormSubmitState build() => const FormSubmitState();

  Future<VehicleDocument?> submit(int vehicleId, DocumentUpload upload) async {
    if (state.isSubmitting) {
      return null;
    }
    state = const FormSubmitState(isSubmitting: true);
    try {
      final document = await ref
          .read(documentRepositoryProvider)
          .upload(vehicleId, upload);
      ref.read(documentChangesProvider.notifier).markChanged();
      state = const FormSubmitState();
      return document;
    } on ApiException catch (error) {
      final errors = error.statusCode == 413 && error.fieldErrors.isEmpty
          ? FormErrors(
              fieldErrors: {
                'file': error.type == null
                    ? DocumentUploadRules.fileTooLargeMessage
                    : error.message,
              },
            )
          : FormErrors.fromApi(
              error,
              fields: DocumentUpload.fieldNames,
              typeToField: const {'file-too-large': 'file'},
            );
      state = FormSubmitState(errors: errors);
      return null;
    }
  }

  void clearFieldError(String field) {
    final errors = state.errors.withoutField(field);
    if (!identical(errors, state.errors)) {
      state = FormSubmitState(isSubmitting: state.isSubmitting, errors: errors);
    }
  }
}

final documentUploadControllerProvider =
    NotifierProvider.autoDispose<DocumentUploadController, FormSubmitState>(
      DocumentUploadController.new,
    );
