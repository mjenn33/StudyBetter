import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_core/quiz_core.dart';

import '../../data/repositories/attempt_repository.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/providers.dart';

/// The numbers shown for one saved attempt.
class AttemptSummary {
  AttemptSummary({
    required this.attempt,
    required this.quizTitle,
    required this.passingScorePercent,
  });

  final AttemptRecord attempt;
  final String quizTitle;

  /// Pass mark of the quiz as it is now.
  final int passingScorePercent;

  int get points => attempt.score;
  int get maxPoints => attempt.maxScore;

  double get percent => maxPoints == 0 ? 0 : points * 100 / maxPoints;

  /// Same integer comparison as `AttemptScore.passed` in quiz_core.
  bool get passed =>
      maxPoints > 0 && points * 100 >= passingScorePercent * maxPoints;

  int get questionCount => attempt.answers.length;
  int get correct => attempt.answers.where((a) => a.isCorrect).length;
  int get skipped => attempt.answers.where((a) => a.isSkipped).length;
  int get incorrect => questionCount - correct - skipped;

  Duration get totalTime => Duration(milliseconds: attempt.durationMs);

  Duration get averageTimePerQuestion => questionCount == 0
      ? Duration.zero
      : Duration(milliseconds: attempt.durationMs ~/ questionCount);
}

/// The saved attempt [attemptId] with what the results screen needs.
final attemptSummaryProvider = FutureProvider.autoDispose
    .family<AttemptSummary, String>((ref, attemptId) async {
      final attempt = await ref
          .read(attemptRepositoryProvider)
          .getById(attemptId);
      if (attempt == null) throw ItemNotFoundException(attemptId);
      final quiz = await ref
          .read(quizRepositoryProvider)
          .getById(attempt.quizId, includeDeleted: true);
      final settings = quiz?.document.settings ?? const QuizSettings();
      return AttemptSummary(
        attempt: attempt,
        quizTitle: quiz?.document.title ?? 'Quiz',
        passingScorePercent: settings.passingScorePercent,
      );
    }, retry: (_, _) => null);

/// A short duration for people: `45 s`, `2 min 5 s`, `1 h 3 min`.
String formatDuration(Duration d) {
  final seconds = (d.inMilliseconds / 1000).round();
  if (seconds < 60) return '$seconds s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) {
    final rest = seconds % 60;
    return rest == 0 ? '$minutes min' : '$minutes min $rest s';
  }
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h $rest min';
}
