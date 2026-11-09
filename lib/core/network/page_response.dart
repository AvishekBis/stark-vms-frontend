/// Generic page wrapper returned by every list endpoint:
/// `{content, page, size, totalElements, totalPages}`.
///
/// Shared by all features (vehicles now; drivers, documents and maintenance
/// in v2.0).
class PageResponse<T> {
  const PageResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromItem,
  ) {
    final rawContent = json['content'];
    final items = rawContent is List
        ? rawContent.whereType<Map<String, dynamic>>().map(fromItem).toList()
        : <T>[];
    return PageResponse<T>(
      content: List.unmodifiable(items),
      page: _int(json['page']),
      size: _int(json['size'], fallback: items.length),
      totalElements: _int(json['totalElements'], fallback: items.length),
      totalPages: _int(json['totalPages']),
    );
  }

  final List<T> content;

  /// Zero-based page index.
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get isEmpty => content.isEmpty;
  bool get hasPrevious => page > 0;
  bool get hasNext => page + 1 < totalPages;

  static int _int(Object? value, {int fallback = 0}) {
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }
}
