import 'api_exception.dart';

/// Server errors of a form submission, split into "under a field" and
/// "general" so each message lands in the right place.
class FormErrors {
  const FormErrors({this.fieldErrors = const {}, this.message});

  /// Maps an [ApiException] onto a form with [fields].
  ///
  /// * 400 / 409 `errors[]` entries for known fields go under that field,
  /// * a Problem Details `type` ending in a key of [typeToField] (e.g.
  ///   `duplicate-driver-phone` → `phone`) goes under that field when the
  ///   body has no `errors[]`,
  /// * everything else becomes [message] (never lost).
  factory FormErrors.fromApi(
    ApiException error, {
    required Set<String> fields,
    Map<String, String> typeToField = const {},
  }) {
    final known = <String, String>{
      for (final entry in error.fieldErrors.entries)
        if (fields.contains(entry.key)) entry.key: entry.value,
    };
    if (known.isEmpty) {
      final type = error.type;
      for (final entry in typeToField.entries) {
        if (type != null && type.endsWith(entry.key)) {
          known[entry.value] = error.message;
          break;
        }
      }
    }
    final unmapped = [
      for (final entry in error.fieldErrors.entries)
        if (!fields.contains(entry.key)) entry.value,
    ];
    final String? message;
    if (known.isEmpty) {
      message = error.message;
    } else {
      message = unmapped.isEmpty ? null : unmapped.join(' ');
    }
    return FormErrors(fieldErrors: Map.unmodifiable(known), message: message);
  }

  final Map<String, String> fieldErrors;
  final String? message;

  String? errorFor(String field) => fieldErrors[field];

  FormErrors withoutField(String field) {
    if (!fieldErrors.containsKey(field)) {
      return this;
    }
    return FormErrors(
      fieldErrors: Map.unmodifiable(Map.of(fieldErrors)..remove(field)),
      message: message,
    );
  }

  FormErrors withoutMessage() => FormErrors(fieldErrors: fieldErrors);
}

/// Submission state shared by the v2.0 forms and dialogs.
class FormSubmitState {
  const FormSubmitState({
    this.isSubmitting = false,
    this.errors = const FormErrors(),
    this.staleVersionMessage,
  });

  /// A rejected submission. A 409 `stale-version` (contract 7.2.3) is kept
  /// apart in [staleVersionMessage] so the screen can offer "Reload" instead
  /// of showing it like any other error.
  factory FormSubmitState.failed(
    ApiException error, {
    required Set<String> fields,
    Map<String, String> typeToField = const {},
  }) {
    if (error.isStaleVersion) {
      return FormSubmitState(staleVersionMessage: error.message);
    }
    return FormSubmitState(
      errors: FormErrors.fromApi(
        error,
        fields: fields,
        typeToField: typeToField,
      ),
    );
  }

  final bool isSubmitting;
  final FormErrors errors;

  /// The server `detail` of a 409 `stale-version`, until the dialog showed it.
  final String? staleVersionMessage;

  bool get isStale => staleVersionMessage != null;

  String? errorFor(String field) => errors.errorFor(field);
  String? get errorMessage => errors.message;

  /// The same state without the stale-version flag (after the dialog).
  FormSubmitState withoutStaleVersion() =>
      FormSubmitState(isSubmitting: isSubmitting, errors: errors);
}
