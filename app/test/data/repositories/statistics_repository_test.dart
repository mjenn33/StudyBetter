import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/attempt_repository.dart';
import 'package:study_better/data/repositories/statistics_repository.dart';

final _t0 = DateTime.utc(2026, 10, 1, 9);

void main() {
  late AppDatabase db;
  late AttemptRepository attempts;
  late StatisticsRepository statistics;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    attempts = AttemptRepository(db);
    statistics = StatisticsRepository(db);
    for (final id in ['quiz-1', 'quiz-2']) {
      await db
          .into(db.quizzes)
          .insert(
            QuizzesCompanion.insert(
              id: id,
              title: id,
              document: '{}',
              version: 1,
              origin: LibraryOrigin.local,
              updatedAt: _t0,
            ),
          );
    }
  });
  tearDown(() => db.close());

  AttemptRecord attempt(
    String id, {
    String quizId = 'quiz-1',
    required DateTime startedAt,
    required int score,
    required int maxScore,
    required List<AnswerRecord> answers,
    bool isPractice = false,
  }) => AttemptRecord(
    id: id,
    quizId: quizId,
    quizVersion: 1,
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 2)),
    score: score,
    maxScore: maxScore,
    durationMs: answers.fold(0, (sum, answer) => sum + answer.timeMs),
    isPractice: isPractice,
    answers: answers,
  );

  const correctQ1 = AnswerRecord(
    questionId: 'q1',
    selectedOptionIds: ['a'],
    isCorrect: true,
    timeMs: 1000,
  );
  const incorrectQ1 = AnswerRecord(
    questionId: 'q1',
    selectedOptionIds: ['b'],
    isCorrect: false,
    timeMs: 3000,
  );
  const incorrectQ2 = AnswerRecord(
    questionId: 'q2',
    selectedOptionIds: [],
    isCorrect: false,
    timeMs: 2000,
  );
  const removedQuestion = AnswerRecord(
    questionId: 'removed-q',
    selectedOptionIds: ['a'],
    isCorrect: true,
    timeMs: 4000,
  );

  test('per-quiz statistics preserve historical question accuracy', () async {
    await attempts.save(
      attempt(
        'old',
        startedAt: _t0,
        score: 1,
        maxScore: 2,
        answers: const [correctQ1, incorrectQ2],
      ),
    );
    await attempts.save(
      attempt(
        'new',
        startedAt: _t0.add(const Duration(days: 1)),
        score: 2,
        maxScore: 2,
        answers: const [incorrectQ1, removedQuestion],
      ),
    );
    await attempts.save(
      attempt(
        'practice',
        startedAt: _t0.add(const Duration(days: 2)),
        score: 2,
        maxScore: 2,
        answers: const [correctQ1],
        isPractice: true,
      ),
    );

    final result = await statistics.forQuiz('quiz-1');

    expect(result.attemptCount, 2);
    expect(result.scores.map((score) => score.attemptId), ['old', 'new']);
    expect(result.bestScore!.attemptId, 'new');
    expect(result.lastScore!.attemptId, 'new');
    expect(result.averageScorePercent, 75);
    expect(result.averageTimePerQuestion, const Duration(milliseconds: 2500));
    expect(
      result.questionAccuracy
          .map(
            (accuracy) => (
              accuracy.questionId,
              accuracy.correctCount,
              accuracy.answerCount,
            ),
          )
          .toList(),
      [('q2', 0, 1), ('q1', 1, 2), ('removed-q', 1, 1)],
    );

    final includingPractice = await statistics.forQuiz(
      'quiz-1',
      includePractice: true,
    );
    expect(includingPractice.attemptCount, 3);
  });

  test(
    'global statistics include totals and thirty days of activity',
    () async {
      final now = DateTime.utc(2026, 10, 30, 15);
      await attempts.save(
        attempt(
          'first-day',
          startedAt: DateTime.utc(2026, 10, 1, 12),
          score: 1,
          maxScore: 2,
          answers: const [correctQ1, incorrectQ2],
        ),
      );
      await attempts.save(
        attempt(
          'today',
          startedAt: DateTime.utc(2026, 10, 30, 8),
          score: 0,
          maxScore: 1,
          answers: const [incorrectQ1],
        ),
      );
      await attempts.save(
        attempt(
          'older',
          quizId: 'quiz-2',
          startedAt: DateTime.utc(2026, 9, 30, 12),
          score: 1,
          maxScore: 1,
          answers: const [removedQuestion],
        ),
      );
      await attempts.save(
        attempt(
          'practice',
          startedAt: DateTime.utc(2026, 10, 30, 10),
          score: 1,
          maxScore: 1,
          answers: const [correctQ1],
          isPractice: true,
        ),
      );

      final result = await statistics.global(now: now);

      expect(result.quizzesTaken, 2);
      expect(result.questionsAnswered, 4);
      expect(result.correctAnswers, 2);
      expect(result.overallAccuracy, 50);
      expect(result.attemptsPerDay, hasLength(30));
      expect(result.attemptsPerDay.first.date, DateTime.utc(2026, 10, 1));
      expect(result.attemptsPerDay.first.count, 1);
      expect(result.attemptsPerDay.last.date, DateTime.utc(2026, 10, 30));
      expect(result.attemptsPerDay.last.count, 1);
      expect(
        result.attemptsPerDay
            .where((day) => day.date == DateTime.utc(2026, 10, 2))
            .single
            .count,
        0,
      );
    },
  );
}
