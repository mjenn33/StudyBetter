import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// A score recorded at the end of one quiz attempt.
class AttemptScore {
  const AttemptScore({
    required this.attemptId,
    required this.recordedAt,
    required this.score,
    required this.maxScore,
  });

  final String attemptId;
  final DateTime recordedAt;
  final int score;
  final int maxScore;

  /// A percentage makes scores from different quiz versions comparable.
  double get percent => maxScore == 0 ? 0 : score * 100 / maxScore;
}

/// Accuracy for a question ID across every saved version of a quiz.
class QuestionAccuracy {
  const QuestionAccuracy({
    required this.questionId,
    required this.correctCount,
    required this.answerCount,
  });

  final String questionId;
  final int correctCount;
  final int answerCount;

  double get percent => answerCount == 0 ? 0 : correctCount * 100 / answerCount;
}

/// Aggregates used by one quiz's statistics screen.
class QuizStatistics {
  const QuizStatistics({
    required this.quizId,
    required this.scores,
    required this.averageTimePerQuestion,
    required this.questionAccuracy,
  });

  final String quizId;

  /// Oldest first, ready to draw as a score trend.
  final List<AttemptScore> scores;
  final Duration averageTimePerQuestion;

  /// Lowest accuracy first, so the weakest questions are first.
  final List<QuestionAccuracy> questionAccuracy;

  int get attemptCount => scores.length;
  AttemptScore? get lastScore => scores.isEmpty ? null : scores.last;
  AttemptScore? get bestScore => scores.isEmpty
      ? null
      : scores.reduce(
          (best, score) => score.percent > best.percent ? score : best,
        );
  double get averageScorePercent => scores.isEmpty
      ? 0
      : scores.map((score) => score.percent).reduce((a, b) => a + b) /
            scores.length;
}

/// The count for a UTC calendar day in the global activity chart.
class DailyAttemptCount {
  const DailyAttemptCount({required this.date, required this.count});

  final DateTime date;
  final int count;
}

/// Aggregates used by the global statistics dashboard.
class GlobalStatistics {
  const GlobalStatistics({
    required this.quizzesTaken,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.attemptsPerDay,
  });

  final int quizzesTaken;
  final int questionsAnswered;
  final int correctAnswers;

  /// Thirty UTC calendar days, oldest first, including days with no attempts.
  final List<DailyAttemptCount> attemptsPerDay;

  double get overallAccuracy =>
      questionsAnswered == 0 ? 0 : correctAnswers * 100 / questionsAnswered;
}

/// Reads metric aggregates from attempts without joining to the mutable quiz
/// document. This preserves historical accuracy when questions are removed or
/// changed in a later quiz version.
class StatisticsRepository {
  StatisticsRepository(this._db);

  final AppDatabase _db;

  Future<QuizStatistics> forQuiz(
    String quizId, {
    bool includePractice = false,
  }) async {
    final attempts = await _attemptsForQuiz(quizId, includePractice);
    final answers = await _answersFor(attempts);
    final scores = [
      for (final attempt in attempts)
        AttemptScore(
          attemptId: attempt.id,
          recordedAt: attempt.finishedAt,
          score: attempt.score,
          maxScore: attempt.maxScore,
        ),
    ];
    final accuracy = <String, _AccuracyTally>{};
    var totalTimeMs = 0;
    for (final answer in answers) {
      totalTimeMs += answer.timeMs;
      final tally = accuracy.putIfAbsent(answer.questionId, _AccuracyTally.new);
      tally.answerCount++;
      if (answer.isCorrect) tally.correctCount++;
    }

    final questionAccuracy =
        [
          for (final entry in accuracy.entries)
            QuestionAccuracy(
              questionId: entry.key,
              correctCount: entry.value.correctCount,
              answerCount: entry.value.answerCount,
            ),
        ]..sort((a, b) {
          final byAccuracy = a.percent.compareTo(b.percent);
          return byAccuracy != 0
              ? byAccuracy
              : a.questionId.compareTo(b.questionId);
        });

    return QuizStatistics(
      quizId: quizId,
      scores: scores,
      averageTimePerQuestion: Duration(
        milliseconds: answers.isEmpty ? 0 : totalTimeMs ~/ answers.length,
      ),
      questionAccuracy: questionAccuracy,
    );
  }

  Future<GlobalStatistics> global({
    DateTime? now,
    bool includePractice = false,
  }) async {
    final attempts = await _allAttempts(includePractice);
    final answers = await _answersFor(attempts);
    final reference = (now ?? DateTime.now()).toUtc();
    final today = DateTime.utc(reference.year, reference.month, reference.day);
    final firstDay = today.subtract(const Duration(days: 29));
    final counts = <DateTime, int>{};
    for (final attempt in attempts) {
      final started = attempt.startedAt.toUtc();
      final day = DateTime.utc(started.year, started.month, started.day);
      if (!day.isBefore(firstDay) && !day.isAfter(today)) {
        counts.update(day, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    return GlobalStatistics(
      quizzesTaken: attempts.map((attempt) => attempt.quizId).toSet().length,
      questionsAnswered: answers.length,
      correctAnswers: answers.where((answer) => answer.isCorrect).length,
      attemptsPerDay: [
        for (var offset = 0; offset < 30; offset++)
          DailyAttemptCount(
            date: firstDay.add(Duration(days: offset)),
            count: counts[firstDay.add(Duration(days: offset))] ?? 0,
          ),
      ],
    );
  }

  Future<List<Attempt>> _attemptsForQuiz(String quizId, bool includePractice) {
    final query = _db.select(_db.attempts)
      ..where((attempt) {
        final forQuiz = attempt.quizId.equals(quizId);
        return includePractice
            ? forQuiz
            : forQuiz & attempt.isPractice.equals(false);
      })
      ..orderBy([(attempt) => OrderingTerm.asc(attempt.finishedAt)]);
    return query.get();
  }

  Future<List<Attempt>> _allAttempts(bool includePractice) {
    final query = _db.select(_db.attempts)
      ..where(
        (attempt) => includePractice
            ? const Constant(true)
            : attempt.isPractice.equals(false),
      );
    return query.get();
  }

  Future<List<AttemptAnswer>> _answersFor(List<Attempt> attempts) {
    if (attempts.isEmpty) return Future.value(const []);
    return (_db.select(_db.attemptAnswers)..where(
          (answer) =>
              answer.attemptId.isIn(attempts.map((attempt) => attempt.id)),
        ))
        .get();
  }
}

class _AccuracyTally {
  var answerCount = 0;
  var correctCount = 0;
}
