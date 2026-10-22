import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// The user's answer to one question in an attempt.
class AnswerRecord {
  const AnswerRecord({
    required this.questionId,
    required this.selectedOptionIds,
    required this.isCorrect,
    required this.timeMs,
  });

  final String questionId;

  /// Empty when the question was skipped.
  final List<String> selectedOptionIds;
  final bool isCorrect;
  final int timeMs;

  bool get isSkipped => selectedOptionIds.isEmpty;
}

/// One finished play-through of a quiz with every answer. Personal data:
/// stored only on the device, never in the quiz document.
class AttemptRecord {
  const AttemptRecord({
    required this.id,
    required this.quizId,
    required this.quizVersion,
    required this.startedAt,
    required this.finishedAt,
    required this.score,
    required this.maxScore,
    required this.durationMs,
    this.isPractice = false,
    required this.answers,
  });

  final String id;
  final String quizId;

  /// Quiz `version` that was played.
  final int quizVersion;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int score;
  final int maxScore;
  final int durationMs;
  final bool isPractice;
  final List<AnswerRecord> answers;
}

/// Stores quiz attempts and their answers.
class AttemptRepository {
  AttemptRepository(this._db);

  final AppDatabase _db;

  /// Saves [attempt] and all its answers in one transaction.
  Future<void> save(AttemptRecord attempt) {
    return _db.transaction(() async {
      await _db
          .into(_db.attempts)
          .insert(
            AttemptsCompanion.insert(
              id: attempt.id,
              quizId: attempt.quizId,
              quizVersion: attempt.quizVersion,
              startedAt: attempt.startedAt.toUtc(),
              finishedAt: attempt.finishedAt.toUtc(),
              score: attempt.score,
              maxScore: attempt.maxScore,
              durationMs: attempt.durationMs,
              isPractice: Value(attempt.isPractice),
            ),
          );
      await _db.batch((batch) {
        batch.insertAll(_db.attemptAnswers, [
          for (final answer in attempt.answers)
            AttemptAnswersCompanion.insert(
              attemptId: attempt.id,
              questionId: answer.questionId,
              selectedOptionIds: answer.selectedOptionIds,
              isCorrect: answer.isCorrect,
              timeMs: answer.timeMs,
            ),
        ]);
      });
    });
  }

  Future<AttemptRecord?> getById(String id) async {
    final row = await (_db.select(
      _db.attempts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return (await _withAnswers([row])).single;
  }

  /// Attempts of [quizId], most recent first.
  Future<List<AttemptRecord>> listForQuiz(
    String quizId, {
    bool includePractice = true,
  }) async => _withAnswers(await _forQuiz(quizId, includePractice).get());

  /// Like [listForQuiz], updating when attempts are added or removed.
  Stream<List<AttemptRecord>> watchForQuiz(
    String quizId, {
    bool includePractice = true,
  }) => _forQuiz(quizId, includePractice).watch().asyncMap(_withAnswers);

  SimpleSelectStatement<$AttemptsTable, Attempt> _forQuiz(
    String quizId,
    bool includePractice,
  ) {
    return _db.select(_db.attempts)
      ..where((a) {
        final ofQuiz = a.quizId.equals(quizId);
        return includePractice ? ofQuiz : ofQuiz & a.isPractice.equals(false);
      })
      ..orderBy([(a) => OrderingTerm.desc(a.startedAt)]);
  }

  Future<List<AttemptRecord>> _withAnswers(List<Attempt> rows) async {
    if (rows.isEmpty) return const [];
    final answerRows = await (_db.select(
      _db.attemptAnswers,
    )..where((a) => a.attemptId.isIn(rows.map((r) => r.id)))).get();

    final byAttempt = <String, List<AnswerRecord>>{};
    for (final a in answerRows) {
      (byAttempt[a.attemptId] ??= []).add(
        AnswerRecord(
          questionId: a.questionId,
          selectedOptionIds: a.selectedOptionIds,
          isCorrect: a.isCorrect,
          timeMs: a.timeMs,
        ),
      );
    }

    return [
      for (final r in rows)
        AttemptRecord(
          id: r.id,
          quizId: r.quizId,
          quizVersion: r.quizVersion,
          startedAt: r.startedAt,
          finishedAt: r.finishedAt,
          score: r.score,
          maxScore: r.maxScore,
          durationMs: r.durationMs,
          isPractice: r.isPractice,
          answers: byAttempt[r.id] ?? const [],
        ),
    ];
  }
}
