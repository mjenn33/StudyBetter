import 'package:meta/meta.dart';

import '../models/quiz.dart';

/// How a question was answered.
enum AnswerOutcome { correct, incorrect, skipped }

/// Scores one answer: [AnswerOutcome.skipped] when nothing is selected,
/// [AnswerOutcome.correct] when the selected options are exactly the correct
/// ones (order and duplicates don't matter), otherwise
/// [AnswerOutcome.incorrect]. Partially correct answers to `multiple`
/// questions score nothing.
AnswerOutcome scoreAnswer(Question question, Iterable<String> selected) {
  final chosen = selected.toSet();
  if (chosen.isEmpty) return AnswerOutcome.skipped;
  final correct = question.correctOptionIds.toSet();
  return chosen.length == correct.length && chosen.containsAll(correct)
      ? AnswerOutcome.correct
      : AnswerOutcome.incorrect;
}

/// The result of one question within an attempt.
@immutable
class QuestionScore {
  const QuestionScore({
    required this.questionId,
    required this.outcome,
    required this.points,
    required this.maxPoints,
  });

  final String questionId;
  final AnswerOutcome outcome;

  /// [maxPoints] when correct, otherwise 0.
  final int points;
  final int maxPoints;

  bool get isCorrect => outcome == AnswerOutcome.correct;
}

/// The result of a whole attempt.
@immutable
class AttemptScore {
  const AttemptScore({
    required this.questions,
    required this.passingScorePercent,
  });

  /// One entry per scored question, in the order given to [scoreAttempt].
  final List<QuestionScore> questions;
  final int passingScorePercent;

  int get points => questions.fold(0, (sum, q) => sum + q.points);
  int get maxPoints => questions.fold(0, (sum, q) => sum + q.maxPoints);

  /// Score as a percentage of [maxPoints] (0–100); 0 when there is nothing to
  /// score.
  double get percent => maxPoints == 0 ? 0 : points * 100 / maxPoints;

  /// Whether the score reaches [passingScorePercent]. Compared in integers so
  /// rounding can't flip a result on the boundary.
  bool get passed =>
      maxPoints > 0 && points * 100 >= passingScorePercent * maxPoints;

  int get correct => _count(AnswerOutcome.correct);
  int get incorrect => _count(AnswerOutcome.incorrect);
  int get skipped => _count(AnswerOutcome.skipped);

  int _count(AnswerOutcome outcome) =>
      questions.where((q) => q.outcome == outcome).length;
}

/// Scores an attempt at [quiz].
///
/// [answers] maps question ids to the selected option ids; questions missing
/// from it count as skipped. [questions] limits scoring to the questions that
/// were asked (e.g. a "weakest questions" practice round) and defaults to all
/// of [quiz]'s questions.
AttemptScore scoreAttempt(
  Quiz quiz,
  Map<String, Iterable<String>> answers, {
  Iterable<Question>? questions,
}) {
  return AttemptScore(
    passingScorePercent: quiz.settings.passingScorePercent,
    questions: [
      for (final question in questions ?? quiz.questions)
        _scoreQuestion(question, answers[question.id] ?? const []),
    ],
  );
}

QuestionScore _scoreQuestion(Question question, Iterable<String> selected) {
  final outcome = scoreAnswer(question, selected);
  return QuestionScore(
    questionId: question.id,
    outcome: outcome,
    points: outcome == AnswerOutcome.correct ? question.points : 0,
    maxPoints: question.points,
  );
}
