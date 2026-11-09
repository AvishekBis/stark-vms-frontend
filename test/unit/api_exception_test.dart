import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stark_vms_frontend/core/network/api_exception.dart';

void main() {
  group('ApiException.fromProblemDetails', () {
    test('parses a 409 duplicate with errors[] (FR-V05)', () {
      final error = ApiException.fromProblemDetails({
        'type': 'https://stark-vms/errors/duplicate-vehicle-number',
        'title': 'Duplicate vehicle number',
        'status': 409,
        'detail': 'Vehicle number DHK-1234 is already registered.',
        'instance': '/api/v1/vehicles',
        'errors': [
          {
            'field': 'vehicleNumber',
            'message': 'Vehicle number DHK-1234 is already registered.',
          },
        ],
      });

      expect(error.kind, ApiErrorKind.http);
      expect(error.statusCode, 409);
      expect(error.isConflict, isTrue);
      expect(error.title, 'Duplicate vehicle number');
      expect(error.type, 'https://stark-vms/errors/duplicate-vehicle-number');
      expect(error.message, 'Vehicle number DHK-1234 is already registered.');
      expect(error.fieldErrors, {
        'vehicleNumber': 'Vehicle number DHK-1234 is already registered.',
      });
    });

    test(
      'parses a 400 with several field errors and keeps the first per field',
      () {
        final error = ApiException.fromProblemDetails({
          'status': 400,
          'title': 'Validation failed',
          'detail': 'Request has invalid fields.',
          'errors': [
            {'field': 'vehicleNumber', 'message': 'must not be blank'},
            {
              'field': 'manufactureYear',
              'message': 'must be between 1980 and 2027',
            },
            {'field': 'vehicleNumber', 'message': 'second message'},
            {'field': null, 'message': 'ignored'},
            'not an object',
          ],
        });

        expect(error.isValidation, isTrue);
        expect(error.fieldErrors, {
          'vehicleNumber': 'must not be blank',
          'manufactureYear': 'must be between 1980 and 2027',
        });
      },
    );

    test('without errors[] the field map is empty', () {
      final error = ApiException.fromProblemDetails({
        'status': 404,
        'title': 'Not found',
        'detail': 'Vehicle 99 was not found.',
      });

      expect(error.isNotFound, isTrue);
      expect(error.fieldErrors, isEmpty);
      expect(error.message, 'Vehicle 99 was not found.');
    });

    test('uses the HTTP status and a default message for a non-JSON body', () {
      final error = ApiException.fromProblemDetails(
        '<html>Bad gateway</html>',
        statusCode: 502,
      );

      expect(error.statusCode, 502);
      expect(
        error.message,
        'Something went wrong on the server. Please try again.',
      );
    });

    test('falls back to the title when detail is missing', () {
      final error = ApiException.fromProblemDetails({
        'status': 403,
        'title': 'Forbidden',
      });

      expect(error.isForbidden, isTrue);
      expect(error.message, 'Forbidden');
    });
  });

  group('ApiException.fromDioException', () {
    final options = RequestOptions(path: '/vehicles');

    test('maps timeouts to a friendly cold-start message', () {
      final error = ApiException.fromDioException(
        DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );

      expect(error.kind, ApiErrorKind.timeout);
      expect(error.message, contains('waking up'));
    });

    test('maps connection errors to a network message', () {
      final error = ApiException.fromDioException(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );

      expect(error.kind, ApiErrorKind.network);
      expect(error.message, contains('Cannot reach the server'));
    });

    test('parses the body of a bad response', () {
      final error = ApiException.fromDioException(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 401,
            data: {
              'status': 401,
              'title': 'Unauthorized',
              'detail': 'Invalid email or password.',
            },
          ),
        ),
      );

      expect(error.isUnauthorized, isTrue);
      expect(error.message, 'Invalid email or password.');
    });
  });
}
