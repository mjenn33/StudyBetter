import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_better/app/router.dart';
import 'package:study_better/data/database/app_database.dart';
import 'package:study_better/data/repositories/attempt_repository.dart';
import 'package:study_better/data/repositories/quiz_repository.dart';
import 'package:study_better/features/quizzes/quiz_routes.dart';
import 'package:study_better/features/results/attempt_summary.dart';

import '../../helpers.dart';
import '../play/player_controller_test.dart' show playQuiz;

AttemptRecord _attempt({
  String id = 'a1',
  required String quizId,
  int score = 3,
  int maxScore = 4,
  int durationMs = 95000,
  List<AnswerRecord>? answers,
}) => AttemptRecord(
  id: id,
  quizId: quizId,
  quizVersion: 1,
  startedAt: DateTime.utc(2026, 10, 22, 9),
  finishedAt: DateTime.utc(2026, 10, 22, 9, 2),
  score: score,
  maxScore: maxScore,
  durationMs: durationMs,
  answers:
      answers ??
      const [
        AnswerRecord(
          questionId: 'q1',
          selectedOptionIds: ['b'],
          isCorrect: true,
          timeMs: 30000,
        ),
        AnswerRecord(
          questionId: 'q2',
          selectedOptionIds: ['a'],
          isCorrect: false,
          timeMs: 40000,
        ),
        AnswerRecord(
          questionId: 'q3',
          selectedOptionIds: [],
          isCorrect: false,
          timeMs: 25000,
        ),
      ],
);

void main() {
  group('AttemptSummary', () {
    AttemptSummary summary({int score = 3, int max = 4, int pass = 70}) =>
        AttemptSummary(
          attempt: _attempt(quizId: 'q', score: score, maxScore: max),
          quizTitle: 'Quiz',
          passingScorePercent: pass,
        );

    test('counts correct, incorrect and skipped answers', () {
      final s = summary();
      expect((s.correct, s.incorrect, s.skipped), (1, 1, 1));
      expect(s.questionCount, 3);
    });

    test('percent and pass/fail', () {
      expect(summary().percent, 75);
      expect(summary().passed, isTrue);
      expect(summary(pass: 76).passed, isFalse);
      expect(summary(score: 0, max: 0).percent, 0);
      expect(summary(score: 0, max: 0).passed, isFalse);
    });

    test('total and average time', () {
      expect(summary().totalTime, const Duration(seconds: 95));
      expect(
        summary().averageTimePerQuestion,
        const Duration(milliseconds: 31666),
      );
    });

    test('formatDuration', () {
      expect(formatDuration(const Duration(milliseconds: 400)), '0 s');
      expect(formatDuration(const Duration(seconds: 45)), '45 s');
      expect(formatDuration(const Duration(milliseconds: 59600)), '1 min');
      expect(formatDuration(const Duration(seconds: 125)), '2 min 5 s');
      expect(formatDuration(const Duration(minutes: 60)), '1 h');
      expect(formatDuration(const Duration(minutes: 63)), '1 h 3 min');
    });
  });

  group('ResultsScreen', () {
    late AppDatabase db;
    late QuizRepository quizzes;
    late AttemptRepository attempts;

    setUp(() {
      db = testDatabase();
      quizzes = QuizRepository(db);
      attempts = AttemptRepository(db);
    });
    tearDown(() => db.close());

    final quiz = playQuiz();

    /// Opens the results of a saved attempt directly.
    Future<void> openResults(WidgetTester tester, AttemptRecord attempt) async {
      await quizzes.import(quiz);
      await attempts.save(attempt);
      final container = await pumpApp(
        tester,
        db: db,
        size: const Size(800, 1200),
      );
      container.read(routerProvider).go(QuizPaths.results(quiz.id, attempt.id));
      await tester.pumpAndSettle();
    }

    testWidgets('shows score, verdict, counts and times', (tester) async {
      await openResults(tester, _attempt(quizId: quiz.id));

      expect(find.text('Play'), findsWidgets); // quiz title in the app bar
      expect(find.text('Passed'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('3 / 4 points · pass mark 70%'), findsOneWidget);
      Finder stat(String label, String value) => find.descendant(
        of: find.widgetWithText(Card, label),
        matching: find.text(value),
      );
      expect(stat('Correct', '1'), findsOneWidget);
      expect(stat('Incorrect', '1'), findsOneWidget);
      expect(stat('Skipped', '1'), findsOneWidget);
      expect(stat('Total time', '1 min 35 s'), findsOneWidget);
      expect(stat('Per question', '32 s'), findsOneWidget);
    });

    testWidgets('a failed attempt says so', (tester) async {
      await openResults(tester, _attempt(quizId: quiz.id, score: 1));

      expect(find.text('Not passed'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('review answers opens the review page', (tester) async {
      await openResults(tester, _attempt(quizId: quiz.id));

      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();

      expect(find.text('Play review'), findsOneWidget);
      expect(find.text('1. One?'), findsOneWidget);
      expect(find.text('2. Many?'), findsOneWidget);
      expect(find.text('3. Three?'), findsOneWidget);
      Finder answerLine(String text) => find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == text,
      );
      expect(answerLine('Your answer: B'), findsOneWidget);
      expect(answerLine('Correct answer: B'), findsOneWidget);
      expect(answerLine('Your answer: Skipped'), findsOneWidget);
      expect(answerLine('Correct answer: A, C'), findsOneWidget);
    });

    testWidgets('review filters to incorrect and skipped answers', (
      tester,
    ) async {
      await openResults(tester, _attempt(quizId: quiz.id));
      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Incorrect only'));
      await tester.pumpAndSettle();

      expect(find.text('1. One?'), findsNothing);
      expect(find.text('1. Many?'), findsOneWidget);
      expect(find.text('2. Three?'), findsOneWidget);
    });

    testWidgets('retry starts a new attempt', (tester) async {
      await openResults(tester, _attempt(quizId: quiz.id));

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1 of 3 · 0 answered'), findsOneWidget);
    });

    testWidgets('back to library', (tester) async {
      await openResults(tester, _attempt(quizId: quiz.id));

      await tester.tap(find.text('Back to library'));
      await tester.pumpAndSettle();

      expect(find.text('Quizzes'), findsWidgets);
      expect(find.byType(ListTile), findsWidgets);
      expect(find.text('Passed'), findsNothing);
    });

    testWidgets('an unknown attempt shows a message', (tester) async {
      await quizzes.import(quiz);
      final container = await pumpApp(tester, db: db);
      container.read(routerProvider).go(QuizPaths.results(quiz.id, 'missing'));
      await tester.pumpAndSettle();

      expect(find.text('This attempt no longer exists.'), findsOneWidget);
    });

    testWidgets('finishing a quiz lands on its results', (tester) async {
      await quizzes.import(quiz);
      final container = await pumpApp(
        tester,
        db: db,
        size: const Size(800, 1200),
      );
      container.read(routerProvider).go(QuizPaths.play(quiz.id));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2. B'));
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish').last);
      await tester.pumpAndSettle();

      final saved = (await db.select(db.attempts).get()).single;
      expect(
        container.read(routerProvider).state.uri.path,
        QuizPaths.results(quiz.id, saved.id),
      );
      expect(find.text('1 / 4 points · pass mark 70%'), findsOneWidget);
      expect(find.widgetWithText(Card, 'Skipped'), findsOneWidget);

      // Back goes to the quiz page, not into the finished attempt.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    });
  });
}
