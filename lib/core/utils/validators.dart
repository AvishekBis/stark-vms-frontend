/// Form validators shared by all forms. They mirror the server rules
/// (BR-03) so users get instant feedback; the server still validates.
///
/// Each validator returns `null` when the value is valid, otherwise the
/// message to show under the field.
abstract final class Validators {
  static final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value, {String fieldLabel = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required.';
    }
    return null;
  }

  static String? maxLength(
    String? value,
    int max, {
    String fieldLabel = 'This field',
  }) {
    if (value != null && value.trim().length > max) {
      return '$fieldLabel must be at most $max characters.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, fieldLabel: 'Email');
    if (requiredError != null) {
      return requiredError;
    }
    if (!_email.hasMatch(value!.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    return null;
  }

  static bool containsLetterOrDigit(String value) =>
      _letterOrDigit.hasMatch(value);
}

/// Vehicle form rules (BR-03, API contract section 2).
abstract final class VehicleValidators {
  static const int vehicleNumberMaxLength = 40;
  static const int brandMaxLength = 50;
  static const int modelMaxLength = 50;
  static const int colorMaxLength = 30;
  static const int minManufactureYear = 1980;

  static String? vehicleNumber(String? value) {
    final requiredError = Validators.required(
      value,
      fieldLabel: 'Vehicle number',
    );
    if (requiredError != null) {
      return requiredError;
    }
    final trimmed = value!.trim();
    if (trimmed.length > vehicleNumberMaxLength) {
      return 'Vehicle number must be at most $vehicleNumberMaxLength characters.';
    }
    if (!Validators.containsLetterOrDigit(trimmed)) {
      return 'Vehicle number must contain at least one letter or digit.';
    }
    return null;
  }

  /// Optional year between [minManufactureYear] and next year.
  static String? manufactureYear(String? value, {required int currentYear}) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final year = int.tryParse(value.trim());
    final maxYear = currentYear + 1;
    if (year == null) {
      return 'Enter the year as a number, e.g. 2019.';
    }
    if (year < minManufactureYear || year > maxYear) {
      return 'Year must be between $minManufactureYear and $maxYear.';
    }
    return null;
  }

  static String? brand(String? value) =>
      Validators.maxLength(value, brandMaxLength, fieldLabel: 'Brand');

  static String? model(String? value) =>
      Validators.maxLength(value, modelMaxLength, fieldLabel: 'Model');

  static String? color(String? value) =>
      Validators.maxLength(value, colorMaxLength, fieldLabel: 'Colour');
}
