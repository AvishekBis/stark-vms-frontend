import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/form_errors.dart';
import 'package:stark_vms_frontend/core/utils/formatters.dart';
import 'package:stark_vms_frontend/core/utils/validators.dart';

import '../helpers/fakes_v2.dart';

void main() {
  group('DriverValidators.phone (contract 6.3)', () {
    test('normalizes spaces, hyphens, parentheses and +880', () {
      expect(DriverValidators.normalizePhone(' 01711-000001 '), '01711000001');
      expect(
        DriverValidators.normalizePhone('(017) 11 000 001'),
        '01711000001',
      );
      expect(DriverValidators.normalizePhone('+8801711000001'), '01711000001');
      expect(
        DriverValidators.normalizePhone('+880 1711-000001'),
        '01711000001',
      );
    });

    test('accepts Bangladeshi mobile numbers in any of those formats', () {
      expect(DriverValidators.phone('01711000001'), isNull);
      expect(DriverValidators.phone('01711-000001'), isNull);
      expect(DriverValidators.phone('+880 1711 000001'), isNull);
    });

    test('rejects missing, short, long and non-numeric numbers', () {
      expect(DriverValidators.phone(''), 'Phone is required.');
      expect(DriverValidators.phone('0171100000'), isNotNull);
      expect(DriverValidators.phone('017110000011'), isNotNull);
      expect(DriverValidators.phone('1711000001X'), isNotNull);
      expect(DriverValidators.phone('11711000001'), isNotNull);
    });

    test('name and licence are required with max lengths', () {
      expect(DriverValidators.fullName(' '), 'Full name is required.');
      expect(DriverValidators.fullName('a' * 101), isNotNull);
      expect(DriverValidators.fullName('Rahim Uddin'), isNull);
      expect(DriverValidators.licenseNumber(''), isNotNull);
      expect(DriverValidators.licenseNumber('x' * 41), isNotNull);
      expect(DriverValidators.licenseExpiry(null), isNotNull);
      expect(DriverValidators.licenseExpiry(DateTime(2020)), isNull);
    });
  });

  group('MaintenanceValidators (BR-09)', () {
    test('cost: >= 0 with at most 2 decimals', () {
      expect(MaintenanceValidators.cost('3500'), isNull);
      expect(MaintenanceValidators.cost('3500.5'), isNull);
      expect(MaintenanceValidators.cost('0'), isNull);
      expect(MaintenanceValidators.cost('3,500.00'), isNull);
      expect(MaintenanceValidators.cost(''), 'Cost is required.');
      expect(MaintenanceValidators.cost('-1'), 'Cost cannot be negative.');
      expect(MaintenanceValidators.cost('10.123'), isNotNull);
      expect(MaintenanceValidators.cost('abc'), isNotNull);
      expect(MaintenanceValidators.cost('99999999999'), isNotNull);
      expect(MaintenanceValidators.parseCost('3,500.25'), 3500.25);
    });

    test('service date is required and not in the future', () {
      final today = DateTime(2026, 11, 18, 23, 59);
      expect(
        MaintenanceValidators.serviceDate(DateTime(2026, 11, 18), today: today),
        isNull,
      );
      expect(
        MaintenanceValidators.serviceDate(DateTime(2026, 11, 19), today: today),
        'Service date cannot be in the future.',
      );
      expect(
        MaintenanceValidators.serviceDate(null, today: today),
        'Service date is required.',
      );
    });

    test('odometer is an optional whole number >= 0', () {
      expect(MaintenanceValidators.odometer(''), isNull);
      expect(MaintenanceValidators.odometer('45210'), isNull);
      expect(MaintenanceValidators.odometer('-5'), isNotNull);
      expect(MaintenanceValidators.odometer('1.5'), isNotNull);
      // The server column is a 32-bit INTEGER.
      expect(MaintenanceValidators.odometer('2147483647'), isNull);
      expect(MaintenanceValidators.odometer('2147483648'), isNotNull);
    });
  });

  group('Formatters (v2.0)', () {
    test('money is BDT with thousands separators and 2 decimals', () {
      expect(Formatters.money(3500), 'BDT 3,500.00');
      expect(Formatters.money(48250.5), 'BDT 48,250.50');
      expect(Formatters.money(0), 'BDT 0.00');
      expect(Formatters.money(null), '-');
    });

    test('ISO date, month and file size', () {
      expect(Formatters.isoDate(DateTime(2026, 3, 5)), '2026-03-05');
      expect(Formatters.month('2026-11'), 'November 2026');
      expect(Formatters.fileSize(512), '512 B');
      expect(Formatters.fileSize(182344), '178.1 KB');
      expect(Formatters.fileSize(5 * 1024 * 1024), '5 MB');
    });
  });

  group('FormErrors.fromApi', () {
    test('409 duplicate phone without errors[] goes under phone', () {
      final errors = FormErrors.fromApi(
        problem(
          409,
          type: 'duplicate-driver-phone',
          detail: 'Phone number 01711000001 is already registered to another driver.',
        ),
        fields: const {'phone', 'licenseNumber'},
        typeToField: const {'duplicate-driver-phone': 'phone'},
      );

      expect(errors.errorFor('phone'), contains('already registered'));
      expect(errors.message, isNull);
    });

    test('errors[] entries go under their fields, unknown ones to message', () {
      final errors = FormErrors.fromApi(
        problem(
          400,
          type: 'validation',
          detail: 'Validation failed',
          errors: const [
            {'field': 'cost', 'message': 'Cost must be 0 or more.'},
            {'field': 'other', 'message': 'Something else.'},
          ],
        ),
        fields: const {'cost'},
      );

      expect(errors.errorFor('cost'), 'Cost must be 0 or more.');
      expect(errors.message, 'Something else.');
    });
  });
}
