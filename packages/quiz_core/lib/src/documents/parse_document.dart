import 'dart:convert';

import '../models/flashcard_deck.dart';
import '../models/quiz.dart';
import '../schema.dart';
import 'document_format_exception.dart';
import 'migrations.dart';

/// A parsed quiz or flashcard deck document.
sealed class StudyDocument {
  const StudyDocument();

  DocumentKind get kind;

  /// The document as JSON in the current schema version.
  Map<String, dynamic> toJson();
}

final class QuizDocument extends StudyDocument {
  const QuizDocument(this.quiz);

  final Quiz quiz;

  @override
  DocumentKind get kind => DocumentKind.quiz;

  @override
  Map<String, dynamic> toJson() => quiz.toJson();
}

final class DeckDocument extends StudyDocument {
  const DeckDocument(this.deck);

  final FlashcardDeck deck;

  @override
  DocumentKind get kind => DocumentKind.flashcardDeck;

  @override
  Map<String, dynamic> toJson() => deck.toJson();
}

/// Reads a quiz or deck document of any supported schema version.
///
/// Checks `kind`, upgrades older versions with [migrations] and builds the
/// model. Throws [DocumentFormatException] for anything that is not a
/// readable document; it does not apply content rules (use `validateQuiz` /
/// `validateDeck` afterwards).
StudyDocument parseDocument(
  Map<String, dynamic> json, {
  Map<int, Migration> migrations = documentMigrations,
}) {
  final kindValue = json['kind'];
  final kind = kindValue is String
      ? DocumentKind.fromWireName(kindValue)
      : null;
  if (kind == null) {
    final known = DocumentKind.values.map((k) => '"${k.wireName}"').join(', ');
    throw DocumentFormatException(
      kindValue == null
          ? 'Missing "kind" (expected one of $known).'
          : 'Unknown kind ${jsonEncode(kindValue)} (expected one of $known).',
      path: 'kind',
    );
  }

  final migrated = migrateDocument(json, migrations: migrations);
  try {
    return switch (kind) {
      DocumentKind.quiz => QuizDocument(Quiz.fromJson(migrated)),
      DocumentKind.flashcardDeck => DeckDocument(
        FlashcardDeck.fromJson(migrated),
      ),
    };
  } on DocumentFormatException {
    rethrow;
  } catch (error) {
    // json_serializable throws TypeError / ArgumentError for missing or
    // mistyped fields; report them uniformly.
    throw DocumentFormatException(
      'The ${kind.wireName} document has missing or invalid fields: $error',
    );
  }
}

/// Decodes [source] (for example the contents of an imported `.json` file)
/// and parses it with [parseDocument].
StudyDocument parseDocumentString(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw DocumentFormatException('Not valid JSON: ${error.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const DocumentFormatException('Expected a JSON object.');
  }
  return parseDocument(decoded);
}
