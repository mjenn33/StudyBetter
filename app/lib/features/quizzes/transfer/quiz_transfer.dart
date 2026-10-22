import 'dart:convert';

import 'package:quiz_core/quiz_core.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/quiz_repository.dart';

/// The JSON written to an exported quiz file: the document in the current
/// schema version, indented for people who open it.
String exportQuizJson(Quiz quiz) =>
    '${const JsonEncoder.withIndent('  ').convert(quiz.toJson())}\n';

/// A file name for [quiz], e.g. `World Capitals!` → `world-capitals.json`.
String exportFileName(Quiz quiz) {
  final slug = quiz.title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return '${slug.isEmpty ? 'quiz' : slug}.json';
}

/// Thrown when a file can't be imported as a quiz.
class QuizImportException implements Exception {
  const QuizImportException(this.message);

  final String message;

  @override
  String toString() => 'QuizImportException: $message';
}

/// Reads a quiz from file [contents] (any supported schema version) and
/// returns it with its validation problems.
///
/// Throws [QuizImportException] when the file isn't a readable quiz.
(Quiz, List<ValidationIssue>) readQuizFile(String contents) {
  final StudyDocument document;
  try {
    document = parseDocumentString(contents);
  } on DocumentFormatException catch (e) {
    throw QuizImportException(e.message);
  }
  return switch (document) {
    QuizDocument(:final quiz) => (quiz, validateQuiz(quiz)),
    DeckDocument() => throw const QuizImportException(
      'This file contains a flashcard deck, not a quiz.',
    ),
  };
}

/// How to import a quiz whose id is already in the library.
enum ImportConflictChoice { replace, copy }

/// Stores imported quizzes in the library.
class QuizImporter {
  QuizImporter(this._quizzes, {String Function()? newId})
    : _newId = newId ?? const Uuid().v4;

  final QuizRepository _quizzes;
  final String Function() _newId;

  /// What the library already has under [quiz]'s id: `null` if nothing (or
  /// only a deleted item, which an import simply replaces).
  Future<ExistingQuiz?> existing(Quiz quiz) async {
    final entry = await _quizzes.getById(quiz.id);
    if (entry == null) return null;
    return ExistingQuiz(
      title: entry.document.title,
      canReplace: !entry.isReadOnly,
    );
  }

  /// Stores [quiz] and returns the stored quiz.
  ///
  /// Without a [choice] the quiz is new (or only a deleted quiz has its id)
  /// and is stored exactly as in the file. [ImportConflictChoice.replace]
  /// overwrites the existing quiz with the file's content as its next
  /// version; [ImportConflictChoice.copy] stores it under a new id.
  Future<Quiz> import(Quiz quiz, {ImportConflictChoice? choice}) =>
      switch (choice) {
        null => _quizzes.import(quiz),
        ImportConflictChoice.replace => _quizzes.save(quiz),
        ImportConflictChoice.copy => _quizzes.import(
          quiz.copyWith(id: _newId()),
        ),
      };
}

/// A quiz in the library with the same id as an imported one.
class ExistingQuiz {
  const ExistingQuiz({required this.title, required this.canReplace});

  final String title;

  /// False for downloaded read-only quizzes: they can only be kept, so the
  /// import becomes a copy.
  final bool canReplace;
}
