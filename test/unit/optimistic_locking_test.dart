import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_enums.dart';
import 'package:stark_vms_frontend/features/vehicles/data/vehicle_repository.dart';
import 'package:stark_vms_frontend/features/vehicles/presentation/vehicle_form_controller.dart';

import '../helpers/fakes.dart';
import '../helpers/recording_adapter.dart';

/// v1.1 optimistic locking on vehicles (ADR 0023, contract 6.2): a loaded
/// vehicle keeps its `version`, the PUT sends it back, the POST never does,
/// and a 409 `stale-version` is recognised as such.
void main() {
  const staleDetail =
      'This vehicle was changed by someone else since you opened it. Reload '
      'and try again.';
  final stale = ApiException.fromProblemDetails({
    'type': 'https://stark-vms/errors/stale-version',
    'title': 'Record changed',
    'status': 409,
    'detail': staleDetail,
    'instance': '/api/v1/vehicles/7',
  });
  const input = VehicleInput(
    vehicleNumber: 'DHK-1234',
    vehicleType: VehicleType.car,
  );

  group('version in VehicleResponse', () {
    test('is parsed', () {
      final vehicle = Vehicle.fromJson({
        'id': 1,
        'vehicleNumber': 'DHK-1',
        'vehicleType': 'CAR',
        'version': 3,
      });

      expect(vehicle.version, 3);
    });

    test('a missing version reads as 0 (new vehicle)', () {
      final vehicle = Vehicle.fromJson({
        'id': 1,
        'vehicleNumber': 'DHK-1',
        'vehicleType': 'CAR',
      });

      expect(vehicle.version, 0);
    });
  });

  group('version in request bodies', () {
    test('the update body carries the version, the create body does not', () {
      expect(input.toUpdateJson(3)['version'], 3);
      expect(input.toJson().containsKey('version'), isFalse);
      expect(input.toUpdateJson(3)..remove('version'), input.toJson());
    });

    test('ApiVehicleRepository sends version in PUT and not in POST', () async {
      final adapter = RecordingAdapter(
        (_) => const CannedResponse(
          200,
          body: {
            'id': 1,
            'vehicleNumber': 'DHK-1234',
            'vehicleType': 'CAR',
            'version': 4,
          },
        ),
      );
      final repository = ApiVehicleRepository(apiClientFor(adapter));

      final updated = await repository.update(1, input, version: 3);
      expect(adapter.last.method, 'PUT');
      expect(adapter.last.path, '/vehicles/1');
      expect((adapter.last.data as Map)['version'], 3);
      expect(updated.version, 4);

      await repository.create(input);
      expect(adapter.last.method, 'POST');
      expect((adapter.last.data as Map).containsKey('version'), isFalse);
    });
  });

  group('409 stale-version', () {
    test('ApiException.isStaleVersion matches only that 409', () {
      expect(stale.isStaleVersion, isTrue);
      expect(stale.message, staleDetail);
      expect(stale.fieldErrors, isEmpty);
      expect(
        ApiException.fromProblemDetails({
          'type': 'https://stark-vms/errors/duplicate-vehicle-number',
          'status': 409,
          'detail': 'x',
        }).isStaleVersion,
        isFalse,
      );
      expect(
        ApiException.fromProblemDetails({
          'type': 'https://stark-vms/errors/stale-version',
          'status': 400,
          'detail': 'x',
        }).isStaleVersion,
        isFalse,
      );
    });
  });

  group('VehicleFormController', () {
    ProviderContainer containerWith(FakeVehicleRepository repository) {
      final container = ProviderContainer(
        overrides: [vehicleRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        vehicleFormControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      return container;
    }

    test('updates with the version the vehicle was loaded with', () async {
      final repository = FakeVehicleRepository(
        seed: [testVehicle(id: 7, version: 3)],
      );
      final container = containerWith(repository);

      final saved = await container
          .read(vehicleFormControllerProvider.notifier)
          .submit(existing: repository.vehicles.single, input: input);

      expect(repository.updateVersions, [3]);
      expect(saved?.version, 4);
    });

    test('a create never goes through update', () async {
      final repository = FakeVehicleRepository();
      final container = containerWith(repository);

      await container
          .read(vehicleFormControllerProvider.notifier)
          .submit(input: input);

      expect(repository.updateVersions, isEmpty);
      expect(repository.vehicles, hasLength(1));
    });

    test('a stale save sets isStale, not a field or general error', () async {
      final repository = FakeVehicleRepository(
        seed: [testVehicle(id: 7, version: 1)],
        saveError: stale,
      );
      final container = containerWith(repository);
      final controller = container.read(vehicleFormControllerProvider.notifier);

      final saved = await controller.submit(
        existing: repository.vehicles.single,
        input: input,
      );

      final state = container.read(vehicleFormControllerProvider);
      expect(saved, isNull);
      expect(state.isStale, isTrue);
      expect(state.staleVersionMessage, staleDetail);
      expect(state.fieldErrors, isEmpty);
      expect(state.errorMessage, isNull);

      controller.clearStaleVersion();
      expect(container.read(vehicleFormControllerProvider).isStale, isFalse);
    });

    test('any other 409 stays a normal error', () async {
      final repository = FakeVehicleRepository(
        seed: [testVehicle(id: 7)],
        saveError: ApiException.fromProblemDetails({
          'type': 'https://stark-vms/errors/conflict',
          'status': 409,
          'detail': 'Other conflict.',
        }),
      );
      final container = containerWith(repository);

      await container
          .read(vehicleFormControllerProvider.notifier)
          .submit(existing: repository.vehicles.single, input: input);

      final state = container.read(vehicleFormControllerProvider);
      expect(state.isStale, isFalse);
      expect(state.errorMessage, 'Other conflict.');
    });
  });
}
