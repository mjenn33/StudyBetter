import 'package:meta/meta.dart';

/// What is wrong, so callers (the editor, the server) can show their own
/// message for each case.
enum ValidationCode {
  /// The document id is not a UUID.
  invalidId,

  /// A required id is empty.
  emptyId,

  /// An id is used more than once where it must be unique.
  duplicateId,

  /// Required text (title, prompt, option text, card side) is empty.
  emptyText,

  /// The quiz has no questions.
  noQuestions,

  /// A question has fewer than [minOptions] options.
  tooFewOptions,

  /// A question has more than [maxOptions] options.
  tooManyOptions,

  /// A question has no correct option.
  noCorrectOption,

  /// A `single` question has more than one correct option.
  multipleCorrectInSingle,

  /// A correct option id does not match any option of the question.
  unknownOptionId,

  /// The deck has no cards.
  noCards,

  /// A number is outside its allowed range.
  outOfRange,
}

/// Minimum number of options per question.
const minOptions = 2;

/// Maximum number of options per question.
const maxOptions = 10;

/// One problem found in a document.
@immutable
class ValidationIssue {
  const ValidationIssue(this.path, this.code, this.message);

  /// Location in the JSON document, e.g. `questions[2].options[0].text`.
  final String path;

  final ValidationCode code;

  /// English description for logs and API error responses.
  final String message;

  Map<String, Object> toJson() => {
    'path': path,
    'code': code.name,
    'message': message,
  };

  @override
  bool operator ==(Object other) =>
      other is ValidationIssue &&
      other.path == path &&
      other.code == code &&
      other.message == message;

  @override
  int get hashCode => Object.hash(path, code, message);

  @override
  String toString() => '$path: $message (${code.name})';
}
