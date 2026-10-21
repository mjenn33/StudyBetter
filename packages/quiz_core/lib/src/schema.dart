/// The `schemaVersion` written to every quiz and deck document.
///
/// Bump it only together with a migration in `quiz_core` and a test that
/// upgrades an old document (see CLAUDE.md).
const int currentSchemaVersion = 1;

/// The `kind` field that identifies what a JSON document contains.
enum DocumentKind {
  quiz('quiz'),
  flashcardDeck('flashcardDeck');

  const DocumentKind(this.wireName);

  /// The value used in JSON.
  final String wireName;

  /// Returns the kind for a JSON `kind` value, or `null` if it is unknown.
  static DocumentKind? fromWireName(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}
