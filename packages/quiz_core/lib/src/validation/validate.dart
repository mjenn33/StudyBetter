import '../models/flashcard_deck.dart';
import '../models/quiz.dart';
import 'validation_issue.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Checks [quiz] against the document rules and returns every problem found;
/// an empty list means the quiz is valid. Never throws.
List<ValidationIssue> validateQuiz(Quiz quiz) {
  final issues = <ValidationIssue>[];
  _checkMetadata(issues, quiz.id, quiz.title, quiz.version);

  final settings = quiz.settings;
  final limit = settings.timeLimitSeconds;
  if (limit != null && limit <= 0) {
    issues.add(
      const ValidationIssue(
        'settings.timeLimitSeconds',
        ValidationCode.outOfRange,
        'Time limit must be positive or null.',
      ),
    );
  }
  if (settings.passingScorePercent < 0 || settings.passingScorePercent > 100) {
    issues.add(
      const ValidationIssue(
        'settings.passingScorePercent',
        ValidationCode.outOfRange,
        'Passing score must be between 0 and 100.',
      ),
    );
  }

  if (quiz.questions.isEmpty) {
    issues.add(
      const ValidationIssue(
        'questions',
        ValidationCode.noQuestions,
        'A quiz needs at least one question.',
      ),
    );
  }
  _checkIds(issues, 'questions', [for (final q in quiz.questions) q.id]);
  for (final (i, question) in quiz.questions.indexed) {
    _checkQuestion(issues, 'questions[$i]', question);
  }
  return issues;
}

/// Checks [deck] against the document rules and returns every problem found;
/// an empty list means the deck is valid. Never throws.
List<ValidationIssue> validateDeck(FlashcardDeck deck) {
  final issues = <ValidationIssue>[];
  _checkMetadata(issues, deck.id, deck.title, deck.version);

  if (deck.cards.isEmpty) {
    issues.add(
      const ValidationIssue(
        'cards',
        ValidationCode.noCards,
        'A deck needs at least one card.',
      ),
    );
  }
  _checkIds(issues, 'cards', [for (final c in deck.cards) c.id]);
  for (final (i, card) in deck.cards.indexed) {
    _checkText(issues, 'cards[$i].front', card.front, 'Card front');
    _checkText(issues, 'cards[$i].back', card.back, 'Card back');
  }
  return issues;
}

void _checkMetadata(
  List<ValidationIssue> issues,
  String id,
  String title,
  int version,
) {
  if (!_uuid.hasMatch(id)) {
    issues.add(
      const ValidationIssue(
        'id',
        ValidationCode.invalidId,
        'Id must be a UUID.',
      ),
    );
  }
  _checkText(issues, 'title', title, 'Title');
  if (version < 1) {
    issues.add(
      const ValidationIssue(
        'version',
        ValidationCode.outOfRange,
        'Version must be 1 or greater.',
      ),
    );
  }
}

void _checkQuestion(List<ValidationIssue> issues, String path, Question q) {
  _checkText(issues, '$path.prompt', q.prompt, 'Question prompt');

  if (q.options.length < minOptions) {
    issues.add(
      ValidationIssue(
        '$path.options',
        ValidationCode.tooFewOptions,
        'A question needs at least $minOptions options.',
      ),
    );
  } else if (q.options.length > maxOptions) {
    issues.add(
      ValidationIssue(
        '$path.options',
        ValidationCode.tooManyOptions,
        'A question can have at most $maxOptions options.',
      ),
    );
  }
  _checkIds(issues, '$path.options', [for (final o in q.options) o.id]);
  for (final (j, option) in q.options.indexed) {
    _checkText(issues, '$path.options[$j].text', option.text, 'Option text');
  }

  final correct = q.correctOptionIds;
  if (correct.isEmpty) {
    issues.add(
      ValidationIssue(
        '$path.correctOptionIds',
        ValidationCode.noCorrectOption,
        'Mark at least one option as correct.',
      ),
    );
  } else if (q.type == QuestionType.single && correct.toSet().length > 1) {
    issues.add(
      ValidationIssue(
        '$path.correctOptionIds',
        ValidationCode.multipleCorrectInSingle,
        'A single-answer question must have exactly one correct option.',
      ),
    );
  }
  final optionIds = {for (final o in q.options) o.id};
  final seen = <String>{};
  for (final (k, id) in correct.indexed) {
    final itemPath = '$path.correctOptionIds[$k]';
    if (!optionIds.contains(id)) {
      issues.add(
        ValidationIssue(
          itemPath,
          ValidationCode.unknownOptionId,
          'Correct option "$id" is not one of the options.',
        ),
      );
    } else if (!seen.add(id)) {
      issues.add(
        ValidationIssue(
          itemPath,
          ValidationCode.duplicateId,
          'Option "$id" is marked correct more than once.',
        ),
      );
    }
  }

  if (q.points < 1) {
    issues.add(
      ValidationIssue(
        '$path.points',
        ValidationCode.outOfRange,
        'Points must be 1 or greater.',
      ),
    );
  }
}

/// Reports empty ids and every repeated id after its first use.
void _checkIds(List<ValidationIssue> issues, String path, List<String> ids) {
  final seen = <String>{};
  for (final (i, id) in ids.indexed) {
    if (id.trim().isEmpty) {
      issues.add(
        ValidationIssue('$path[$i].id', ValidationCode.emptyId, 'Id is empty.'),
      );
    } else if (!seen.add(id)) {
      issues.add(
        ValidationIssue(
          '$path[$i].id',
          ValidationCode.duplicateId,
          'Id "$id" is used more than once.',
        ),
      );
    }
  }
}

void _checkText(
  List<ValidationIssue> issues,
  String path,
  String value,
  String label,
) {
  if (value.trim().isEmpty) {
    issues.add(
      ValidationIssue(path, ValidationCode.emptyText, '$label is empty.'),
    );
  }
}
