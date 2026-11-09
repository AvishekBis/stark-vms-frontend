import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/page_response.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';

void main() {
  group('PageResponse.fromJson', () {
    test('parses the page wrapper and its items', () {
      final page = PageResponse.fromJson({
        'content': [
          {
            'id': 12,
            'vehicleNumber': 'DHK-1234',
            'vehicleType': 'CAR',
            'status': 'ACTIVE',
          },
          {
            'id': 13,
            'vehicleNumber': 'DHK-5678',
            'vehicleType': 'BUS',
            'status': 'INACTIVE',
          },
        ],
        'page': 1,
        'size': 2,
        'totalElements': 57,
        'totalPages': 29,
      }, Vehicle.fromJson);

      expect(page.content.map((v) => v.vehicleNumber), [
        'DHK-1234',
        'DHK-5678',
      ]);
      expect(page.page, 1);
      expect(page.size, 2);
      expect(page.totalElements, 57);
      expect(page.totalPages, 29);
      expect(page.hasPrevious, isTrue);
      expect(page.hasNext, isTrue);
    });

    test('handles an empty page and null content', () {
      final page = PageResponse.fromJson({
        'content': null,
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
      }, Vehicle.fromJson);

      expect(page.isEmpty, isTrue);
      expect(page.totalElements, 0);
      expect(page.hasPrevious, isFalse);
      expect(page.hasNext, isFalse);
    });

    test('falls back to the item count when totals are missing', () {
      final page = PageResponse.fromJson({
        'content': [
          {
            'id': 1,
            'vehicleNumber': 'A1',
            'vehicleType': 'CAR',
            'status': 'ACTIVE',
          },
        ],
      }, Vehicle.fromJson);

      expect(page.size, 1);
      expect(page.totalElements, 1);
      expect(page.page, 0);
    });
  });
}
