import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/attempt_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/providers.dart';

/// One saved answer paired with the question as it is currently stored.
class ReviewedAnswer {
  const ReviewedAnswer({required this.answer, required this.question});

  final AnswerRecord answer;

  /// Null when the question was deleted from the quiz after this attempt.
  final Question? question;
}

/// Data needed to present the answer review for a finished attempt.
class AnswerReview {
  const AnswerReview({
    required this.attempt,
    required this.quizTitle,
    required this.answers,
  });

  final AttemptRecord attempt;
  final String quizTitle;
  final List<ReviewedAnswer> answers;
}

/// Loads an attempt and matches each saved answer to its quiz question.
final answerReviewProvider = FutureProvider.autoDispose
    .family<AnswerReview, String>((ref, attemptId) async {
      final attempt = await ref
          .read(attemptRepositoryProvider)
          .getById(attemptId);
      if (attempt == null) throw ItemNotFoundException(attemptId);

      final entry = await ref
          .read(quizRepositoryProvider)
          .getById(attempt.quizId, includeDeleted: true);
      final questions = {
        for (final question in entry?.document.questions ?? const <Question>[])
          question.id: question,
      };
      return AnswerReview(
        attempt: attempt,
        quizTitle: entry?.document.title ?? 'Quiz',
        answers: [
          for (final answer in attempt.answers)
            ReviewedAnswer(
              answer: answer,
              question: questions[answer.questionId],
            ),
        ],
      );
    }, retry: (_, _) => null);
