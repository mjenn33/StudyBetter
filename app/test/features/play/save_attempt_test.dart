import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_core/quiz_core.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/database/database_provider.dart';
import 'package:study_better/data/repositories/attempt_repository.dart';
import 'package:study_better/data/repositories/providers.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/play/attempt_record.dart';
import 'package:study_better/features/play/player_controller.dart';

import '../../helpers.dart';
import 'player_controller_test.dart' show playQuiz;

void main() {
  group('attemptRecordFrom', () {
    final quiz = playQuiz().copyWith(version: 5);
    final [q1, q2, q3] = quiz.questions;
    final finished = FinishedAttempt(
      quiz: quiz,
      // Asked in a shuffled order.
      questions: [q3, q1, q2],
      selections: {
        'q1': {'b'},
        'q2': {'c', 'a'},
      },
      score: scoreAttempt(
        quiz,
        {
          'q1': ['b'],
          'q2': ['c', 'a'],
        },
        questions: [q3, q1, q2],
      ),
      startedAt: DateTime.utc(2026, 10, 22, 9),
      finishedAt: DateTime.utc(2026, 10, 22, 9, 2),
      durationMs: 90000,
      questionTimeMs: const {'q1': 30000, 'q2': 50000, 'q3': 10000},
    );

    test('maps the attempt and one answer per asked question', () {
      final record = attemptRecordFrom(finished, id: 'a1');

      expect(record.id, 'a1');
      expect(record.quizId, quiz.id);
      expect(record.quizVersion, 5);
      expect(record.score, 3);
      expect(record.maxScore, 4);
      expect(record.durationMs, 90000);
      expect(record.isPractice, isFalse);
      expect(record.answers.map((a) => a.questionId), ['q3', 'q1', 'q2']);
    });

    test('answers keep selections in option order, correctness and time', () {
      final [a3, a1, a2] = attemptRecordFrom(finished, id: 'a1').answers;

      expect(a3.isSkipped, isTrue);
      expect(a3.isCorrect, isFalse);
      expect(a3.timeMs, 10000);
      expect(a1.selectedOptionIds, ['b']);
      expect(a1.isCorrect, isTrue);
      expect(a2.selectedOptionIds, ['a', 'c']);
      expect(a2.isCorrect, isTrue);
      expect(a2.timeMs, 50000);
    });
  });

  group('PlayerController.finishAndSave', () {
    late AppDatabase db;
    late ProviderContainer container;
    var now = DateTime.utc(2026, 10, 22, 9);

    setUp(() {
      db = testDatabase();
      now = DateTime.utc(2026, 10, 22, 9);
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          playerRandomProvider.overrideWithValue(Random(1)),
          playerClockProvider.overrideWith((ref) => Clock(() => now)),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('stores the attempt with every answer', () async {
      final quiz = playQuiz();
      await container.read(quizRepositoryProvider).import(quiz);
      final provider = playerProvider(quiz.id);
      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      final player = container.read(provider.notifier);

      player.select('b');
      now = now.add(const Duration(seconds: 3));
      player.next();
      now = now.add(const Duration(seconds: 2));
      final (id, attempt) = await player.finishAndSave();

      final saved = await container.read(attemptRepositoryProvider).getById(id);
      expect(saved!.quizId, quiz.id);
      expect(saved.quizVersion, quiz.version);
      expect(saved.score, attempt.score.points);
      expect(saved.maxScore, 4);
      expect(saved.startedAt, DateTime.utc(2026, 10, 22, 9));
      expect(saved.finishedAt, DateTime.utc(2026, 10, 22, 9, 0, 5));
      expect(saved.durationMs, 5000);
      expect(saved.answers.map((a) => (a.questionId, a.timeMs, a.isCorrect)), [
        ('q1', 3000, true),
        ('q2', 2000, false),
        ('q3', 0, false),
      ]);
    });

    test('practice player saves an attempt marked as practice', () async {
      final quiz = playQuiz();
      await container.read(quizRepositoryProvider).import(quiz);
      final provider = practicePlayerProvider(
        PracticeLaunch(quizId: quiz.id, questionIds: const {'q2'}),
      );
      container.listen(provider, (_, _) {});
      await container.read(provider.future);

      final (id, _) = await container.read(provider.notifier).finishAndSave();
      final saved = await container.read(attemptRepositoryProvider).getById(id);
      expect(saved!.isPractice, isTrue);
      expect(saved.answers.map((answer) => answer.questionId), ['q2']);
    });
  });

  group('PlayerScreen', () {
    late AppDatabase db;
    late QuizRepository quizzes;

    setUp(() {
      db = testDatabase();
      quizzes = QuizRepository(db);
    });
    tearDown(() => db.close());

    Future<void> start(WidgetTester tester, {QuizSettings? settings}) async {
      await quizzes.import(
        playQuiz(settings: settings ?? const QuizSettings()),
      );
      await pumpApp(tester, db: db, size: const Size(800, 1000));
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await tester.pumpAndSettle();
    }

    Future<List<AttemptRecord>> savedAttempts() async {
      final rows = await db.select(db.attempts).get();
      final repo = AttemptRepository(db);
      return [for (final r in rows) (await repo.getById(r.id))!];
    }

    testWidgets('finishing saves the attempt', (tester) async {
      await start(tester);

      await tester.tap(find.text('2. B'));
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish').last);
      await tester.pumpAndSettle();

      final [attempt] = await savedAttempts();
      expect(attempt.score, 1);
      expect(attempt.maxScore, 4);
      expect(attempt.answers, hasLength(3));
      expect(attempt.answers.where((a) => a.isSkipped), hasLength(2));
    });

    testWidgets('leaving mid-quiz saves nothing', (tester) async {
      await start(tester);

      await tester.tap(find.text('2. B'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      expect(await savedAttempts(), isEmpty);
    });

    testWidgets('running out of time saves the attempt', (tester) async {
      await start(tester, settings: const QuizSettings(timeLimitSeconds: 3));

      await tester.tap(find.text('2. B'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      final [attempt] = await savedAttempts();
      expect(attempt.score, 1);
      expect(attempt.durationMs, 3000);
    });
  });
}
