import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/utils/validators.dart';

void main() {
  group('VehicleValidators.vehicleNumber (BR-03)', () {
    test('requires a value', () {
      expect(VehicleValidators.vehicleNumber(null), isNotNull);
      expect(VehicleValidators.vehicleNumber(''), isNotNull);
      expect(VehicleValidators.vehicleNumber('   '), isNotNull);
    });

    test('accepts typical Bangladeshi formats', () {
      expect(VehicleValidators.vehicleNumber('DHK-1234'), isNull);
      expect(VehicleValidators.vehicleNumber('dhk 1234'), isNull);
      expect(VehicleValidators.vehicleNumber('DHAKA METRO-GA 11-2345'), isNull);
    });

    test('must contain at least one letter or digit', () {
      expect(
        VehicleValidators.vehicleNumber('---'),
        contains('letter or digit'),
      );
      expect(
        VehicleValidators.vehicleNumber(' - - '),
        contains('letter or digit'),
      );
    });

    test('max 40 characters after trimming', () {
      final forty = List.filled(40, 'A').join();
      expect(VehicleValidators.vehicleNumber(forty), isNull);
      expect(VehicleValidators.vehicleNumber('  $forty  '), isNull);
      expect(VehicleValidators.vehicleNumber('${forty}B'), contains('40'));
    });
  });

  group('VehicleValidators.manufactureYear (BR-03)', () {
    const currentYear = 2026;

    test('is optional', () {
      expect(
        VehicleValidators.manufactureYear(null, currentYear: currentYear),
        isNull,
      );
      expect(
        VehicleValidators.manufactureYear('', currentYear: currentYear),
        isNull,
      );
    });

    test('accepts 1980 up to next year', () {
      expect(
        VehicleValidators.manufactureYear('1980', currentYear: currentYear),
        isNull,
      );
      expect(
        VehicleValidators.manufactureYear('2019', currentYear: currentYear),
        isNull,
      );
      expect(
        VehicleValidators.manufactureYear('2027', currentYear: currentYear),
        isNull,
      );
    });

    test('rejects years outside the bounds', () {
      expect(
        VehicleValidators.manufactureYear('1979', currentYear: currentYear),
        contains('1980'),
      );
      expect(
        VehicleValidators.manufactureYear('2028', currentYear: currentYear),
        contains('2027'),
      );
    });

    test('rejects non-numbers', () {
      expect(
        VehicleValidators.manufactureYear('20x9', currentYear: currentYear),
        isNotNull,
      );
    });
  });

  group('optional text max lengths', () {
    String repeat(String char, int count) => List.filled(count, char).join();

    test('brand and model max 50, colour max 30', () {
      expect(VehicleValidators.brand(repeat('B', 50)), isNull);
      expect(VehicleValidators.brand(repeat('B', 51)), isNotNull);
      expect(VehicleValidators.model(repeat('M', 51)), isNotNull);
      expect(VehicleValidators.color(repeat('C', 30)), isNull);
      expect(VehicleValidators.color(repeat('C', 31)), isNotNull);
      expect(VehicleValidators.brand(null), isNull);
    });
  });

  group('login validators', () {
    test('email must be present and well formed', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('admin'), isNotNull);
      expect(Validators.email('admin@stark.local'), isNull);
    });

    test('password must be present', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('secret'), isNull);
    });
  });
}
