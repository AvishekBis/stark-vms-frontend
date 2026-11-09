import 'api_exception.dart';

/// Helpers shared by every repository to turn decoded JSON into models.
abstract final class ResponseParsing {
  static const ApiException unexpectedData = ApiException(
    kind: ApiErrorKind.unknown,
    message: 'The server sent data this app does not understand.',
  );

  static Map<String, dynamic> object(Object? body) {
    if (body is Map<String, dynamic>) {
      return body;
    }
    throw const FormatException('Expected a JSON object.');
  }

  /// A JSON array of objects (non-object entries are skipped).
  static List<Map<String, dynamic>> objectList(Object? body) {
    if (body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    throw const FormatException('Expected a JSON array.');
  }

  /// Runs [parse]; malformed data becomes a friendly [ApiException].
  static T parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw unexpectedData;
    } on TypeError {
      throw unexpectedData;
    }
  }
}
