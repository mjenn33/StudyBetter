import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/app/router.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/attempt_repository.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/quizzes/quiz_routes.dart';

import '../../helpers.dart';
import '../play/player_controller_test.dart' show playQuiz;

void main() {
  late AppDatabase db;
  late QuizRepository quizzes;
  late AttemptRepository attempts;

  setUp(() {
    db = testDatabase();
    quizzes = QuizRepository(db);
    attempts = AttemptRepository(db);
  });
  tearDown(() => db.close());

  AttemptRecord attempt(
    String id, {
    required String quizId,
    required DateTime startedAt,
    required int score,
  }) => AttemptRecord(
    id: id,
    quizId: quizId,
    quizVersion: 1,
    startedAt: startedAt,
    finishedAt: startedAt.add(const Duration(minutes: 2)),
    score: score,
    maxScore: 4,
    durationMs: 40000,
    answers: const [
      AnswerRecord(
        questionId: 'q1',
        selectedOptionIds: ['b'],
        isCorrect: true,
        timeMs: 10000,
      ),
      AnswerRecord(
        questionId: 'q2',
        selectedOptionIds: ['a'],
        isCorrect: false,
        timeMs: 10000,
      ),
      AnswerRecord(
        questionId: 'q3',
        selectedOptionIds: [],
        isCorrect: false,
        timeMs: 10000,
      ),
    ],
  );

  testWidgets('shows summary, score chart and answer-review history', (
    tester,
  ) async {
    final quiz = playQuiz();
    await quizzes.import(quiz);
    await attempts.save(
      attempt(
        'old',
        quizId: quiz.id,
        startedAt: DateTime.utc(2026, 10, 20, 12),
        score: 1,
      ),
    );
    await attempts.save(
      attempt(
        'new',
        quizId: quiz.id,
        startedAt: DateTime.utc(2026, 10, 21, 12),
        score: 3,
      ),
    );

    final container = await pumpApp(
      tester,
      db: db,
      size: const Size(800, 1200),
    );
    container.read(routerProvider).go(QuizPaths.stats(quiz.id));
    await tester.pumpAndSettle();

    expect(find.text('Play statistics'), findsOneWidget);
    expect(find.text('Attempts'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('75%'), findsWidgets);
    expect(find.text('Average'), findsOneWidget);
    expect(find.text('50%'), findsWidgets);
    expect(find.text('Last'), findsOneWidget);
    expect(find.text('Score trend'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Attempt history'), findsOneWidget);
    expect(find.text('2026-10-21'), findsOneWidget);

    await tester.tap(find.text('75%').last);
    await tester.pumpAndSettle();
    expect(find.text('Play review'), findsOneWidget);
  });

  testWidgets('explains when a quiz has no attempts', (tester) async {
    final quiz = playQuiz();
    await quizzes.import(quiz);

    final container = await pumpApp(tester, db: db);
    container.read(routerProvider).go(QuizPaths.stats(quiz.id));
    await tester.pumpAndSettle();

    expect(
      find.text('No attempts yet. Play this quiz to see statistics.'),
      findsOneWidget,
    );
  });
}
