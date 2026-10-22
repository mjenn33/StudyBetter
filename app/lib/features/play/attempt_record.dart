import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/attempt_repository.dart';
import 'player_controller.dart';

/// The stored form of [attempt]: one answer per asked question, in the
/// order they were asked, with selected ids in the quiz's option order.
AttemptRecord attemptRecordFrom(
  FinishedAttempt attempt, {
  required String id,
  bool isPractice = false,
}) {
  final outcomes = {
    for (final q in attempt.score.questions) q.questionId: q.outcome,
  };
  return AttemptRecord(
    id: id,
    quizId: attempt.quiz.id,
    quizVersion: attempt.quiz.version,
    startedAt: attempt.startedAt,
    finishedAt: attempt.finishedAt,
    score: attempt.score.points,
    maxScore: attempt.score.maxPoints,
    durationMs: attempt.durationMs,
    isPractice: isPractice,
    answers: [
      for (final question in attempt.questions)
        AnswerRecord(
          questionId: question.id,
          selectedOptionIds: [
            for (final option in question.options)
              if (attempt.selections[question.id]?.contains(option.id) ?? false)
                option.id,
          ],
          isCorrect: outcomes[question.id] == AnswerOutcome.correct,
          timeMs: attempt.questionTimeMs[question.id] ?? 0,
        ),
    ],
  );
}
