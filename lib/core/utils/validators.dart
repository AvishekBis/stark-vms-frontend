import 'dart:convert';

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

/// Driver form rules (FR-DR01, contract 6.3).
abstract final class DriverValidators {
  static const int fullNameMaxLength = 100;
  static const int phoneMaxLength = 20;
  static const int licenseNumberMaxLength = 40;

  static final RegExp _separators = RegExp(r'[\s\-()]');
  static final RegExp _bdMobile = RegExp(r'^0\d{10}$');

  static String? fullName(String? value) {
    final requiredError = Validators.required(value, fieldLabel: 'Full name');
    if (requiredError != null) {
      return requiredError;
    }
    return Validators.maxLength(
      value,
      fullNameMaxLength,
      fieldLabel: 'Full name',
    );
  }

  /// Trim, drop spaces / hyphens / parentheses, `+880` → `0`.
  static String normalizePhone(String raw) {
    final compact = raw.trim().replaceAll(_separators, '');
    return compact.startsWith('+880') ? '0${compact.substring(4)}' : compact;
  }

  static String? phone(String? value) {
    final requiredError = Validators.required(value, fieldLabel: 'Phone');
    if (requiredError != null) {
      return requiredError;
    }
    if (value!.trim().length > phoneMaxLength) {
      return 'Phone must be at most $phoneMaxLength characters.';
    }
    if (!_bdMobile.hasMatch(normalizePhone(value))) {
      return 'Enter a Bangladeshi mobile number, e.g. 01711-000001.';
    }
    return null;
  }

  static String? licenseNumber(String? value) {
    final requiredError = Validators.required(
      value,
      fieldLabel: 'Licence number',
    );
    if (requiredError != null) {
      return requiredError;
    }
    return Validators.maxLength(
      value,
      licenseNumberMaxLength,
      fieldLabel: 'Licence number',
    );
  }

  static String? licenseExpiry(DateTime? value) =>
      value == null ? 'Licence expiry date is required.' : null;
}

/// Maintenance form rules (FR-M01, BR-09, contract 6.6).
abstract final class MaintenanceValidators {
  static const double maxCost = 9999999999.99;
  static const int vendorMaxLength = 100;
  static const int notesMaxLength = 1000;

  /// `odometer_km INTEGER` / Java `Integer` on the server.
  static const int maxOdometerKm = 2147483647;

  static final RegExp _money = RegExp(r'^\d+(\.\d{1,2})?$');

  /// Cost in BDT: required, a number ≥ 0 with at most 2 decimals.
  static String? cost(String? value) {
    final requiredError = Validators.required(value, fieldLabel: 'Cost');
    if (requiredError != null) {
      return requiredError;
    }
    final text = value!.trim().replaceAll(',', '');
    if (text.startsWith('-')) {
      return 'Cost cannot be negative.';
    }
    if (!_money.hasMatch(text)) {
      return 'Enter the cost as a number with up to 2 decimals, e.g. 3500.00.';
    }
    final amount = double.parse(text);
    if (amount > maxCost) {
      return 'Cost must be at most 9,999,999,999.99.';
    }
    return null;
  }

  /// The parsed cost (call after [cost] passed).
  static double parseCost(String value) =>
      double.parse(value.trim().replaceAll(',', ''));

  /// Required, and not after [today] (Asia/Dhaka on the server).
  static String? serviceDate(DateTime? value, {required DateTime today}) {
    if (value == null) {
      return 'Service date is required.';
    }
    final day = DateTime(value.year, value.month, value.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    if (day.isAfter(todayDay)) {
      return 'Service date cannot be in the future.';
    }
    return null;
  }

  static String? odometer(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final km = int.tryParse(value.trim());
    if (km == null || km < 0) {
      return 'Odometer must be a whole number of 0 or more.';
    }
    if (km > maxOdometerKm) {
      return 'Odometer must be at most 2,147,483,647 km.';
    }
    return null;
  }

  static String? vendor(String? value) =>
      Validators.maxLength(value, vendorMaxLength, fieldLabel: 'Vendor');

  static String? notes(String? value) =>
      Validators.maxLength(value, notesMaxLength, fieldLabel: 'Notes');
}

/// User account rules (v2.1, contract 7.3.3, ADR 0024).
abstract final class UserValidators {
  static const int emailMaxLength = 255;
  static const int fullNameMaxLength = 100;

  /// The server's minimum password length.
  static const int passwordMinLength = 8;

  /// BCrypt only reads 72 bytes; the server refuses longer passwords.
  static const int passwordMaxBytes = 72;

  static String? email(String? value) {
    final error = Validators.email(value);
    if (error != null) {
      return error;
    }
    return Validators.maxLength(value, emailMaxLength, fieldLabel: 'Email');
  }

  static String? fullName(String? value) {
    final requiredError = Validators.required(value, fieldLabel: 'Full name');
    if (requiredError != null) {
      return requiredError;
    }
    return Validators.maxLength(
      value,
      fullNameMaxLength,
      fieldLabel: 'Full name',
    );
  }

  /// A new password: 8 characters to 72 bytes in UTF-8 (not trimmed —
  /// spaces count, as on the server). Characters are Unicode code points
  /// like the server's `PasswordPolicy`, so an emoji counts once, not twice.
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.runes.length < passwordMinLength) {
      return 'Password must be at least $passwordMinLength characters.';
    }
    if (utf8.encode(value).length > passwordMaxBytes) {
      return 'Password is too long (at most $passwordMaxBytes bytes; '
          'some characters count as more than one).';
    }
    return null;
  }

  /// "Confirm password" must repeat [password] exactly.
  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Repeat the new password.';
    }
    return value == password ? null : 'The passwords do not match.';
  }
}
