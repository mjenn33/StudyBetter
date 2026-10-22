/// A JSON document could not be read as a quiz or flashcard deck.
///
/// Thrown for structural problems (not JSON, unknown `kind`, unsupported
/// `schemaVersion`, missing or mistyped fields). Content rules such as "at
/// least one question" are reported by `validateQuiz` / `validateDeck`.
class DocumentFormatException implements Exception {
  const DocumentFormatException(this.message, {this.path});

  /// English description, safe to show to the user.
  final String message;

  /// Location in the document, e.g. `schemaVersion`, when known.
  final String? path;

  @override
  String toString() => path == null
      ? 'DocumentFormatException: $message'
      : 'DocumentFormatException: $path: $message';
}
